import uuid

import pytest

from tests.api.routes.test_calendars import account, create

RANGE = {"from": "2026-10-18", "to": "2026-10-19"}
TIMED = {
    "title": "저녁 약속",
    "starts_at": "2026-10-18T19:00:00+09:00",
    "ends_at": "2026-10-18T20:00:00+09:00",
}


@pytest.fixture
def group(client):
    user_a, a = account(client)
    user_b, b = account(client)
    _, c = account(client)
    cal = create(client, a)
    # Direct membership setup keeps event tests independent of invitation rate limits.
    from sqlmodel import Session

    from app.core.db import engine
    from app.models import CalendarMember

    with Session(engine) as session:
        session.add(
            CalendarMember(
                calendar_id=uuid.UUID(cal["id"]),
                user_id=uuid.UUID(user_b["id"]),
                role="member",
                slot=2,
            )
        )
        session.commit()
    return f"/api/v1/calendars/{cal['id']}/events", a, b, c, user_a, user_b


def post(client, path, headers, **changes):
    response = client.post(path, headers=headers, json={**TIMED, **changes})
    assert response.status_code == 201, response.text
    return response.json()


def test_create_read_update_delete_by_author(client, group):
    path, a, b, _, user_a, user_b = group
    event = post(client, path, a, title="  약속  ")
    assert event["title"] == "약속"
    assert event["created_by"] == user_a["id"]
    assert event["starts_at"] == "2026-10-18T10:00:00Z"
    url = path + "/" + event["id"]
    for headers in [a, b]:
        assert client.get(url, headers=headers).json()["id"] == event["id"]
        assert client.get(path, headers=headers, params=RANGE).json()["count"] == 1
    # Owner cannot edit the other member's events either.
    other = post(client, path, b)
    assert other["created_by"] == user_b["id"]
    for headers, target in [(b, url), (a, path + "/" + other["id"])]:
        assert (
            client.patch(target, headers=headers, json={"title": "x"}).status_code
            == 403
        )
        assert client.delete(target, headers=headers).status_code == 403
    r = client.patch(url, headers=a, json={"description": "추가 설명"})
    assert r.status_code == 200
    assert r.json()["starts_at"] == event["starts_at"]
    assert r.json()["updated_at"] >= event["updated_at"]
    assert (
        client.patch(url, headers=a, json={"description": None}).json()["description"]
        is None
    )
    assert client.delete(url, headers=a).status_code == 204
    assert client.get(url, headers=b).status_code == 404


def test_outsider_admin_unauthenticated_and_wrong_calendar(
    client, group, superuser_token_headers
):
    path, a, b, c, _, _ = group
    event = post(client, path, a)
    url = path + "/" + event["id"]
    for headers, status in [(c, 403), (superuser_token_headers, 403), ({}, 401)]:
        assert client.get(path, headers=headers, params=RANGE).status_code == status
        assert client.post(path, headers=headers, json=TIMED).status_code == status
        assert client.get(url, headers=headers).status_code == status
        assert (
            client.patch(url, headers=headers, json={"title": "x"}).status_code
            == status
        )
        assert client.delete(url, headers=headers).status_code == status
    second = create(client, a)
    wrong = f"/api/v1/calendars/{second['id']}/events/{event['id']}"
    assert client.get(wrong, headers=a).status_code == 404
    assert client.patch(wrong, headers=a, json={"title": "x"}).status_code == 404
    assert client.delete(wrong, headers=a).status_code == 404
    assert client.get(path + "/" + str(uuid.uuid4()), headers=b).status_code == 404
    assert (
        client.get(
            f"/api/v1/calendars/{uuid.uuid4()}/events", headers=a, params=RANGE
        ).status_code
        == 404
    )


@pytest.mark.parametrize(
    "changes",
    [
        {"title": "   "},
        {"title": None},
        {"all_day": None},
        {"starts_at": None},
        {"ends_at": "2026-10-18T18:00:00+09:00"},
        {"starts_at": "2026-10-18T10:00:00"},
        {"all_day": True},
        {"created_by": str(uuid.uuid4())},
        {"calendar_id": str(uuid.uuid4())},
        {"id": str(uuid.uuid4())},
        {"title": "x" * 201},
        {"description": "x" * 5001},
    ],
)
def test_bad_create_and_patch_do_not_modify_existing(client, group, changes):
    path, a, _, _, _, _ = group
    event = post(client, path, a)
    url = path + "/" + event["id"]
    assert client.post(path, headers=a, json={**TIMED, **changes}).status_code == 422
    assert client.patch(url, headers=a, json=changes).status_code == 422
    assert client.get(url, headers=a).json() == event


def test_switch_timed_and_all_day_and_partial_validation(client, group):
    path, a, _, _, _, _ = group
    event = post(client, path, a)
    url = path + "/" + event["id"]
    r = client.patch(
        url,
        headers=a,
        json={"all_day": True, "start_date": "2026-10-18", "end_date": "2026-10-19"},
    )
    assert r.status_code == 200, r.text
    assert r.json()["starts_at"] is None and r.json()["ends_at"] is None
    assert (
        client.patch(url, headers=a, json={"end_date": "2026-10-18"}).status_code == 422
    )
    assert client.patch(url, headers=a, json={"start_date": None}).status_code == 422
    r = client.patch(
        url,
        headers=a,
        json={
            "all_day": False,
            "starts_at": TIMED["starts_at"],
            "ends_at": TIMED["ends_at"],
        },
    )
    assert r.status_code == 200
    assert r.json()["start_date"] is None and r.json()["end_date"] is None
    assert client.patch(url, headers=a, json={}).json() == r.json()


def test_overlap_exclusive_boundaries_and_pagination(client, group):
    path, a, _, _, _, _ = group
    # Seoul day starts at the previous UTC date, 15:00.
    post(
        client,
        path,
        a,
        starts_at="2026-10-17T14:00:00Z",
        ends_at="2026-10-17T15:00:00Z",
    )
    post(
        client,
        path,
        a,
        starts_at="2026-10-18T15:00:00Z",
        ends_at="2026-10-18T16:00:00Z",
    )
    spanning = post(
        client,
        path,
        a,
        starts_at="2026-10-17T14:00:00Z",
        ends_at="2026-10-19T15:00:00Z",
    )
    morning = post(
        client,
        path,
        a,
        starts_at="2026-10-17T16:00:00Z",
        ends_at="2026-10-17T17:00:00Z",
    )
    day = client.post(
        path,
        headers=a,
        json={
            "title": "휴가",
            "all_day": True,
            "start_date": "2026-10-18",
            "end_date": "2026-10-19",
        },
    )
    assert day.status_code == 201
    for start, end in [("2026-10-17", "2026-10-18"), ("2026-10-19", "2026-10-20")]:
        assert (
            client.post(
                path,
                headers=a,
                json={
                    "title": "밖",
                    "all_day": True,
                    "start_date": start,
                    "end_date": end,
                },
            ).status_code
            == 201
        )
    r = client.get(path, headers=a, params=RANGE).json()
    expected = [spanning["id"], day.json()["id"], morning["id"]]
    assert r["count"] == 3
    assert [e["id"] for e in r["data"]] == expected
    for skip in range(4):
        page = client.get(
            path, headers=a, params={**RANGE, "skip": skip, "limit": 1}
        ).json()
        assert page["count"] == 3
        assert [e["id"] for e in page["data"]] == expected[skip : skip + 1]


@pytest.mark.parametrize(
    "params",
    [
        {},
        {"from": "2026-10-18"},
        {"from": "bad", "to": "2026-10-19"},
        {"from": "2026-10-18", "to": "2026-10-18"},
        {"from": "2026-10-19", "to": "2026-10-18"},
        {"from": "2026-01-01", "to": "2026-05-01"},
        {**RANGE, "skip": -1},
        {**RANGE, "limit": 201},
        {**RANGE, "limit": 0},
    ],
)
def test_invalid_range(client, group, params):
    path, a, _, _, _, _ = group
    assert client.get(path, headers=a, params=params).status_code == 422


def test_daylight_saving_calendar_range(client):
    _, a = account(client)
    response = client.post(
        "/api/v1/calendars",
        headers=a,
        json={"name": "NY", "timezone": "America/New_York"},
    )
    path = f"/api/v1/calendars/{response.json()['id']}/events"
    # Spring DST day is 23 hours: 05:00 UTC March 8 to 04:00 UTC March 9.
    inside = post(
        client,
        path,
        a,
        starts_at="2026-03-09T03:30:00Z",
        ends_at="2026-03-09T04:00:00Z",
    )
    post(
        client,
        path,
        a,
        starts_at="2026-03-09T04:00:00Z",
        ends_at="2026-03-09T04:30:00Z",
    )
    r = client.get(
        path, headers=a, params={"from": "2026-03-08", "to": "2026-03-09"}
    ).json()
    assert [e["id"] for e in r["data"]] == [inside["id"]]


def test_concurrent_partial_updates_preserve_both_fields(client, group):
    from concurrent.futures import ThreadPoolExecutor
    from threading import Barrier

    from fastapi.testclient import TestClient

    from app.main import app

    path, a, _, _, _, _ = group
    event = post(client, path, a)
    url = path + "/" + event["id"]
    barrier = Barrier(2)

    def patch(body):
        with TestClient(app) as other:
            barrier.wait(timeout=10)
            return other.patch(url, headers=a, json=body).status_code

    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(
            pool.map(patch, [{"title": "새 제목"}, {"description": "새 설명"}])
        )
    assert results == [200, 200]
    final = client.get(url, headers=a).json()
    assert final["title"] == "새 제목"
    assert final["description"] == "새 설명"


def test_timezone_conversion_overflow_is_validation_error(client, group):
    path, a, _, _, _, _ = group
    assert (
        client.get(
            path, headers=a, params={"from": "0001-01-01", "to": "0001-01-02"}
        ).status_code
        == 422
    )
