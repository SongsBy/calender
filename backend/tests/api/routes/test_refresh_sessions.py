import uuid
from concurrent.futures import ThreadPoolExecutor
from datetime import UTC, datetime, timedelta
from threading import Barrier

import jwt
from fastapi.testclient import TestClient
from sqlmodel import Session, select

from app.core.config import settings
from app.core.security import ALGORITHM
from app.main import app
from app.models import RefreshSession, User
from app.services.auth import token_hash
from app.utils import generate_password_reset_token

P = settings.API_V1_STR
PASSWORD = "valid-password-123"


def register(client: TestClient) -> str:
    username = "user_" + uuid.uuid4().hex[:20]
    r = client.post(
        f"{P}/users/signup", json={"username": username, "password": PASSWORD}
    )
    assert r.status_code == 201, r.text
    assert r.json()["email"] is None
    return username


def login(client: TestClient, username: str) -> dict:
    r = client.post(
        f"{P}/login/access-token", data={"username": username, "password": PASSWORD}
    )
    assert r.status_code == 200, r.text
    return r.json()


def headers(pair: dict) -> dict:
    return {"Authorization": "Bearer " + pair["access_token"]}


def refresh(client: TestClient, pair: dict):
    return client.post(
        f"{P}/login/refresh", json={"refresh_token": pair["refresh_token"]}
    )


def test_username_normalization_uniqueness_and_privilege_input(client: TestClient):
    username = "user_" + uuid.uuid4().hex[:20]
    payload = {
        "username": " " + username.upper() + " ",
        "password": PASSWORD,
        "is_superuser": True,
    }
    response = client.post(f"{P}/users/signup", json=payload)
    assert response.status_code == 201
    assert response.json()["username"] == username
    assert response.json()["is_superuser"] is False
    assert client.post(f"{P}/users/signup", json=payload).status_code == 409
    assert login(client, username.upper())["refresh_token"]
    for invalid in ["ab", "email@example.com", "legacy_reserved", "contains space"]:
        assert (
            client.post(
                f"{P}/users/signup", json={"username": invalid, "password": PASSWORD}
            ).status_code
            == 422
        )


def test_rotation_hash_storage_and_replay_revoke_family(
    client: TestClient, db: Session
):
    original = login(client, register(client))
    row = db.exec(
        select(RefreshSession).where(
            RefreshSession.token_hash == token_hash(original["refresh_token"])
        )
    ).one()
    expiry = row.expires_at
    assert row.token_hash != original["refresh_token"]
    assert original["expires_in"] == 900
    rotated = refresh(client, original)
    assert rotated.status_code == 200
    pair = rotated.json()
    assert pair["refresh_token"] != original["refresh_token"]
    replacement = db.exec(
        select(RefreshSession).where(
            RefreshSession.token_hash == token_hash(pair["refresh_token"])
        )
    ).one()
    assert replacement.expires_at == expiry
    assert client.get(f"{P}/users/me", headers=headers(pair)).status_code == 200
    assert refresh(client, original).status_code == 401
    assert refresh(client, pair).status_code == 401
    assert client.get(f"{P}/users/me", headers=headers(pair)).status_code == 401


def test_logout_only_revokes_current_device(client: TestClient):
    username = register(client)
    first, other = login(client, username), login(client, username)
    assert client.post(f"{P}/login/logout", headers=headers(first)).status_code == 204
    assert client.get(f"{P}/users/me", headers=headers(first)).status_code == 401
    assert refresh(client, first).status_code == 401
    assert client.get(f"{P}/users/me", headers=headers(other)).status_code == 200


def test_expired_access_can_refresh_and_wrong_token_types_rejected(client: TestClient):
    pair = login(client, register(client))
    payload = jwt.decode(
        pair["access_token"], settings.SECRET_KEY, algorithms=[ALGORITHM]
    )
    payload["exp"] = datetime.now(UTC) - timedelta(seconds=1)
    expired = jwt.encode(payload, settings.SECRET_KEY, algorithm=ALGORITHM)
    assert (
        client.get(
            f"{P}/users/me", headers={"Authorization": "Bearer " + expired}
        ).status_code
        == 401
    )
    assert refresh(client, pair).status_code == 200
    for token in [
        generate_password_reset_token("test@example.com"),
        pair["refresh_token"],
        jwt.encode(
            {"sub": payload["sub"], "exp": datetime.now(UTC) + timedelta(minutes=5)},
            settings.SECRET_KEY,
            algorithm=ALGORITHM,
        ),
    ]:
        assert (
            client.get(
                f"{P}/users/me", headers={"Authorization": "Bearer " + token}
            ).status_code
            == 401
        )


def test_password_change_revokes_all_devices(client: TestClient):
    username = register(client)
    first, other = login(client, username), login(client, username)
    response = client.patch(
        f"{P}/users/me/password",
        headers=headers(first),
        json={"current_password": PASSWORD, "new_password": "replacement-password-456"},
    )
    assert response.status_code == 200
    for pair in (first, other):
        assert refresh(client, pair).status_code == 401
        assert client.get(f"{P}/users/me", headers=headers(pair)).status_code == 401


def test_expired_refresh_and_inactive_user(client: TestClient, db: Session):
    username = register(client)
    pair = login(client, username)
    row = db.exec(
        select(RefreshSession).where(
            RefreshSession.token_hash == token_hash(pair["refresh_token"])
        )
    ).one()
    row.expires_at = datetime.now(UTC) - timedelta(seconds=1)
    db.add(row)
    db.commit()
    assert refresh(client, pair).status_code == 401
    pair = login(client, username)
    user = db.exec(select(User).where(User.username == username)).one()
    user.is_active = False
    db.add(user)
    db.commit()
    assert refresh(client, pair).status_code == 401
    assert client.get(f"{P}/users/me", headers=headers(pair)).status_code == 401


def test_concurrent_refresh_has_one_winner_then_revokes_family(client: TestClient):
    pair = login(client, register(client))
    barrier = Barrier(2)

    def attempt():
        with TestClient(app) as independent:
            barrier.wait(timeout=10)
            return refresh(independent, pair)

    with ThreadPoolExecutor(max_workers=2) as pool:
        responses = list(pool.map(lambda _: attempt(), range(2)))
    assert sorted(r.status_code for r in responses) == [200, 401]
    winner = next(r.json() for r in responses if r.status_code == 200)
    assert refresh(client, winner).status_code == 401
    assert client.get(f"{P}/users/me", headers=headers(winner)).status_code == 401
