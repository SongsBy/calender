import uuid
from concurrent.futures import ThreadPoolExecutor
from datetime import UTC, datetime, timedelta
from threading import Barrier

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.exc import IntegrityError
from sqlmodel import Session, delete, select

from app.core.db import engine
from app.main import app
from app.models import CalendarInvitation, CalendarMember, InvitationRateLimit
from app.services.calendars import hash_code

P = "/api/v1"


@pytest.fixture(autouse=True)
def fresh_limits():
    with Session(engine) as session:
        session.exec(delete(InvitationRateLimit))
        session.commit()


def account(client):
    username = "cal_" + uuid.uuid4().hex[:20]
    r = client.post(
        P + "/users/signup",
        json={
            "username": username,
            "password": "calendar-pass-123",
            "full_name": username,
        },
    )
    assert r.status_code == 201, r.text
    user = r.json()
    login = client.post(
        P + "/login/access-token",
        data={"username": username, "password": "calendar-pass-123"},
    )
    assert login.status_code == 200
    return user, {"Authorization": "Bearer " + login.json()["access_token"]}


def create(client, headers, name="우리 일정"):
    r = client.post(P + "/calendars", headers=headers, json={"name": name})
    assert r.status_code == 201, r.text
    return r.json()


def invite(client, headers, calendar):
    r = client.post(f"{P}/calendars/{calendar['id']}/invitations", headers=headers)
    assert r.status_code == 201, r.text
    return r.json()


def accept(client, headers, code):
    return client.post(P + "/invitations/accept", headers=headers, json={"code": code})


def test_create_list_detail_and_privacy(client, superuser_token_headers):
    user, owner = account(client)
    _, outsider = account(client)
    cal = create(client, owner, "  우리 일정  ")
    assert cal["name"] == "우리 일정"
    assert cal["timezone"] == "Asia/Seoul"
    assert cal["members"] == [
        {"id": user["id"], "full_name": user["full_name"], "role": "owner", "slot": 1}
    ]
    own = client.get(P + "/calendars", headers=owner).json()
    assert own["count"] == 1
    assert own["data"][0]["id"] == cal["id"]
    for headers in (outsider, superuser_token_headers):
        assert client.get(P + "/calendars", headers=headers).json()["count"] == 0
        assert (
            client.get(f"{P}/calendars/{cal['id']}", headers=headers).status_code == 403
        )
        assert (
            client.post(
                f"{P}/calendars/{cal['id']}/invitations", headers=headers
            ).status_code
            == 403
        )
    assert client.get(f"{P}/calendars/{uuid.uuid4()}", headers=owner).status_code == 404
    assert client.get(P + "/calendars").status_code == 401


def test_two_users_connect_and_code_is_hashed(client):
    _, owner = account(client)
    user_b, member = account(client)
    cal = create(client, owner)
    invitation = invite(client, owner, cal)
    raw = invitation["code"]
    with Session(engine) as session:
        row = session.get(CalendarInvitation, uuid.UUID(invitation["id"]))
        assert row.code_hash == hash_code(raw)
        assert row.code_hash != raw
        assert 23.9 < (row.expires_at - datetime.now(UTC)).total_seconds() / 3600 <= 24
    formatted = " " + "-".join([raw[:4], raw[4:8], raw[8:]]).lower() + " "
    r = accept(client, member, formatted)
    assert r.status_code == 200, r.text
    assert r.json()["members"][1]["id"] == user_b["id"]
    for h in (owner, member):
        assert (
            client.get(P + "/calendars", headers=h).json()["data"][0]["id"] == cal["id"]
        )
        assert (
            len(client.get(f"{P}/calendars/{cal['id']}", headers=h).json()["members"])
            == 2
        )
    assert accept(client, member, raw).status_code == 409
    assert (
        client.post(
            f"{P}/calendars/{cal['id']}/invitations", headers=member
        ).status_code
        == 403
    )
    assert (
        client.post(f"{P}/calendars/{cal['id']}/invitations", headers=owner).status_code
        == 409
    )
    with Session(engine) as session:
        row = session.get(CalendarInvitation, uuid.UUID(invitation["id"]))
        assert row.used_at is not None
        assert row.accepted_by == uuid.UUID(user_b["id"])


def test_self_expired_revoked_and_unknown_codes(client):
    _, owner = account(client)
    _, member = account(client)
    cal = create(client, owner)
    old = invite(client, owner, cal)
    assert (
        accept(client, owner, old["code"]).json()["detail"]["code"] == "ALREADY_MEMBER"
    )
    new = invite(client, owner, cal)
    assert accept(client, member, old["code"]).status_code == 400
    with Session(engine) as session:
        row = session.get(CalendarInvitation, uuid.UUID(new["id"]))
        row.expires_at = datetime.now(UTC) - timedelta(seconds=1)
        session.add(row)
        session.commit()
    assert accept(client, member, new["code"]).status_code == 400
    assert accept(client, member, "A" * 12).status_code == 400
    assert accept(client, member, "bad").status_code == 400
    assert (
        len(client.get(f"{P}/calendars/{cal['id']}", headers=owner).json()["members"])
        == 1
    )


def test_third_user_denied_even_with_unused_code(client):
    _, owner = account(client)
    _, member = account(client)
    _, third = account(client)
    cal = create(client, owner)
    invitation = invite(client, owner, cal)
    assert accept(client, member, invitation["code"]).status_code == 200
    assert accept(client, third, invitation["code"]).status_code == 409
    # Simulate an older independent unused code; membership capacity still applies.
    with Session(engine) as session:
        session.add(
            CalendarInvitation(
                calendar_id=uuid.UUID(cal["id"]),
                created_by=uuid.UUID(cal["members"][0]["id"]),
                code_hash=hash_code("B" * 12),
                expires_at=datetime.now(UTC) + timedelta(hours=1),
            )
        )
        session.commit()
    assert accept(client, third, "B" * 12).json()["detail"]["code"] == "CALENDAR_FULL"
    assert client.get(P + "/calendars", headers=third).json()["count"] == 0


def test_simultaneous_accepts_have_only_one_winner(client):
    _, owner = account(client)
    _, first = account(client)
    _, second = account(client)
    cal = create(client, owner)
    code = invite(client, owner, cal)["code"]
    barrier = Barrier(2)

    def attempt(headers):
        with TestClient(app) as independent:
            barrier.wait(timeout=10)
            return accept(independent, headers, code)

    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(attempt, [first, second]))
    assert sorted(r.status_code for r in results) == [200, 409]
    assert (
        len(client.get(f"{P}/calendars/{cal['id']}", headers=owner).json()["members"])
        == 2
    )


def test_reissue_racing_accept_never_leaves_valid_second_invitation(client):
    _, owner = account(client)
    _, member = account(client)
    cal = create(client, owner)
    code = invite(client, owner, cal)["code"]
    barrier = Barrier(2)

    def issue():
        with TestClient(app) as independent:
            barrier.wait(timeout=10)
            return independent.post(
                f"{P}/calendars/{cal['id']}/invitations", headers=owner
            )

    def join():
        with TestClient(app) as independent:
            barrier.wait(timeout=10)
            return accept(independent, member, code)

    with ThreadPoolExecutor(max_workers=2) as pool:
        future_issue, future_join = pool.submit(issue), pool.submit(join)
        issued, joined = future_issue.result(), future_join.result()
    assert (issued.status_code, joined.status_code) in [(201, 400), (409, 200)]


def test_rate_limits_survive_new_connections_and_reset_after_expiry(client):
    _, owner = account(client)
    _, member = account(client)
    cal = create(client, owner)
    for _ in range(5):
        invite(client, owner, cal)
    blocked = client.post(f"{P}/calendars/{cal['id']}/invitations", headers=owner)
    assert blocked.status_code == 429
    assert int(blocked.headers["Retry-After"]) > 0
    for _ in range(10):
        assert accept(client, member, "A" * 12).status_code == 400
    with TestClient(app) as another_client:
        assert accept(another_client, member, "A" * 12).status_code == 429
    with Session(engine) as session:
        for row in session.exec(select(InvitationRateLimit)).all():
            row.expires_at = datetime.now(UTC) - timedelta(seconds=1)
            session.add(row)
        session.commit()
    assert accept(client, member, "A" * 12).status_code == 400
    assert invite(client, owner, cal)["code"]


def test_ip_limit_cannot_be_bypassed_with_forwarded_header(client):
    for _ in range(3):
        _, user = account(client)
        user["X-Forwarded-For"] = str(uuid.uuid4())
        for _ in range(10):
            assert accept(client, user, "A" * 12).status_code == 400
    _, fourth = account(client)
    assert accept(client, fourth, "A" * 12).status_code == 429


def test_membership_prevents_self_and_admin_account_deletion(
    client, superuser_token_headers
):
    owner_user, owner = account(client)
    member_user, member = account(client)
    cal = create(client, owner)
    assert accept(client, member, invite(client, owner, cal)["code"]).status_code == 200
    for user, headers in [(owner_user, owner), (member_user, member)]:
        assert client.delete(P + "/users/me", headers=headers).status_code == 409
        assert (
            client.delete(
                f"{P}/users/{user['id']}", headers=superuser_token_headers
            ).status_code
            == 409
        )
        assert client.get(P + "/users/me", headers=headers).status_code == 200


def test_database_slot_constraints(client):
    _, owner = account(client)
    extra, _ = account(client)
    cal = create(client, owner)
    for slot, role in [(3, "member"), (1, "member"), (1, "owner")]:
        with Session(engine) as session:
            session.add(
                CalendarMember(
                    calendar_id=uuid.UUID(cal["id"]),
                    user_id=uuid.UUID(extra["id"]),
                    slot=slot,
                    role=role,
                )
            )
            with pytest.raises(IntegrityError):
                session.commit()
            session.rollback()


def test_validation_and_pagination(client):
    _, owner = account(client)
    for body in [
        {"name": " "},
        {"name": "x" * 101},
        {"name": "valid", "timezone": "invalid/zone"},
    ]:
        assert (
            client.post(P + "/calendars", headers=owner, json=body).status_code == 422
        )
    first, second = create(client, owner, "첫 번째"), create(client, owner, "두 번째")
    listing = client.get(P + "/calendars?limit=1&skip=0", headers=owner).json()
    assert listing["count"] == 2
    assert listing["data"][0]["id"] == second["id"]
    assert (
        client.get(P + "/calendars?limit=1&skip=1", headers=owner).json()["data"][0][
            "id"
        ]
        == first["id"]
    )
    assert client.get(P + "/calendars?limit=201", headers=owner).status_code == 422
    assert client.get(P + "/calendars?skip=-1", headers=owner).status_code == 422
