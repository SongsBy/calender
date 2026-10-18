# ruff: noqa: F811
import uuid
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier

from fastapi.testclient import TestClient
from sqlmodel import Session, select

from app.core.db import engine
from app.main import app
from app.models import CalendarInvitation, CalendarMember, Event, EventImportSource
from tests.api.routes.test_calendars import accept, invite
from tests.api.routes.test_event_imports import body
from tests.api.routes.test_events import RANGE, TIMED, group  # noqa: F401


def test_leave_removes_own_events_and_blocks_access(client, group):
    path, a, b, c, _, _ = group
    cal = path.removesuffix("/events")
    owner_event = client.post(path, headers=a, json=TIMED).json()
    client.post(path, headers=b, json=TIMED)
    assert (
        client.post(path + "/import", headers=b, json=body()).json()["created_count"]
        == 1
    )
    assert client.post(cal + "/leave", headers=a).status_code == 409
    assert client.post(cal + "/leave", headers=c).status_code == 403
    assert client.post(cal + "/leave").status_code == 401
    assert client.post(cal + "/leave", headers=b).status_code == 204
    assert client.get("/api/v1/calendars", headers=b).json()["count"] == 0
    for url in [
        cal,
        path + "?from=2026-10-18&to=2026-10-19",
        path + "/" + owner_event["id"],
    ]:
        assert client.get(url, headers=b).status_code == 403
    assert client.post(path, headers=b, json=TIMED).status_code == 403
    assert client.post(path + "/import", headers=b, json=body()).status_code == 403
    listing = client.get(path, headers=a, params=RANGE).json()
    assert [e["id"] for e in listing["data"]] == [owner_event["id"]]
    code = invite(client, a, {"id": cal.split("/")[-1]})["code"]
    assert accept(client, c, code).status_code == 200
    assert client.get(path, headers=c, params=RANGE).json()["count"] == 1


def test_delete_cascades_and_denies_nonowner(client, group):
    path, a, b, c, *_ = group
    cal = path.removesuffix("/events")
    client.post(path + "/import", headers=b, json=body())
    for headers, status in [(b, 403), (c, 403), ({}, 401)]:
        assert client.delete(cal, headers=headers).status_code == status
    assert client.delete(cal, headers=a).status_code == 204
    for headers in [a, b]:
        assert client.get(cal, headers=headers).status_code == 404
        assert client.get("/api/v1/calendars", headers=headers).json()["count"] == 0
    with Session(engine) as session:
        for model in [CalendarMember, CalendarInvitation, Event, EventImportSource]:
            assert not session.exec(
                select(model).where(model.calendar_id == uuid.UUID(cal.split("/")[-1]))
            ).all()


def test_leave_racing_event_creation_cannot_leave_orphan_event(client, group):
    path, a, b, *_ = group
    cal = path.removesuffix("/events")
    barrier = Barrier(2)

    def run(action):
        with TestClient(app) as other:
            barrier.wait(timeout=10)
            return (
                other.post(cal + "/leave", headers=b)
                if action == "leave"
                else other.post(path, headers=b, json=TIMED)
            )

    with ThreadPoolExecutor(max_workers=2) as pool:
        leave, create = list(pool.map(run, ["leave", "create"]))
    assert leave.status_code == 204
    assert create.status_code in [201, 403]
    assert client.get(path, headers=a, params=RANGE).json()["count"] == 0


def test_old_invitation_revoked_after_leave_and_new_invite_works(client):
    from tests.api.routes.test_calendars import account, create

    _, a = account(client)
    _, b = account(client)
    cal = create(client, a)
    old = invite(client, a, cal)["code"]
    assert accept(client, b, old).status_code == 200
    url = f"/api/v1/calendars/{cal['id']}"
    assert client.post(url + "/leave", headers=b).status_code == 204
    assert accept(client, b, old).status_code == 400
    new = invite(client, a, cal)["code"]
    assert accept(client, b, new).status_code == 200
    assert client.delete(url, headers=a).status_code == 204
    assert accept(client, b, new).status_code == 400
