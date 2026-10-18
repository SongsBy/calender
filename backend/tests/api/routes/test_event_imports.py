# ruff: noqa: F811
import uuid
from concurrent.futures import ThreadPoolExecutor

from tests.api.routes.test_events import RANGE, TIMED, group  # noqa: F401


def body():
    return {"installation_id": str(uuid.uuid4()), "events": [{**TIMED, "source_calendar_id": "1", "source_event_id": "2", "occurrence_key": "2026-10-18T10:00:00Z"}]}


def test_import_duplicate_authorization_and_reimport(client, group):
    path, a, b, c, user, _ = group
    data = body()
    assert client.post(path + "/import", headers=c, json=data).status_code == 403
    assert client.post(path + "/import", json=data).status_code == 401
    data["events"] *= 2
    r = client.post(path + "/import", headers=a, json=data)
    assert r.status_code == 200, r.text
    assert (r.json()["created_count"], r.json()["skipped_count"]) == (1, 1)
    event = r.json()["data"][0]
    assert event["created_by"] == user["id"]
    assert client.get(path, headers=b, params=RANGE).json()["count"] == 1
    assert client.post(path + "/import", headers=a, json=data).json()["created_count"] == 0
    assert client.delete(path + "/" + event["id"], headers=b).status_code == 403
    assert client.delete(path + "/" + event["id"], headers=a).status_code == 204
    assert client.post(path + "/import", headers=a, json=data).json()["created_count"] == 1


def test_invalid_batch_is_atomic(client, group):
    path, a, *_ = group
    data = body()
    data["events"].append({**data["events"][0], "ends_at": "2020-01-01T00:00:00Z"})
    assert client.post(path + "/import", headers=a, json=data).status_code == 422
    assert client.get(path, headers=a, params=RANGE).json()["count"] == 0
    data["events"] = [body()["events"][0]] * 101
    assert client.post(path + "/import", headers=a, json=data).status_code == 422


def test_concurrent_import(client, group):
    path, a, *_ = group
    data = body()
    def send(_):
        r = client.post(path + "/import", headers=a, json=data)
        assert r.status_code == 200, r.text
        return r.json()["created_count"]
    with ThreadPoolExecutor(max_workers=2) as pool:
        assert sorted(pool.map(send, range(2))) == [0, 1]
    assert client.get(path, headers=a, params=RANGE).json()["count"] == 1
