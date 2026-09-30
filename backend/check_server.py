"""Smoke-test the access rules and the stock hook against a THROWAWAY PocketBase.

It creates users and items, so never point it at the real database.

    pocketbase serve --dir <empty dir> --http 127.0.0.1:8099
    pocketbase superuser upsert su@test.local testpass123 --dir <same dir>
    python check_server.py http://127.0.0.1:8099 su@test.local testpass123
"""
import json
import sys
import urllib.error
import urllib.request

BASE, SU_EMAIL, SU_PASS = sys.argv[1:4]


def call(method, path, token=None, body=None):
    req = urllib.request.Request(BASE + path, method=method,
                                 data=json.dumps(body).encode() if body is not None else None)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", token)
    try:
        with urllib.request.urlopen(req) as r:
            return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}")


def login(coll, email, pw):
    s, d = call("POST", f"/api/collections/{coll}/auth-with-password", body={"identity": email, "password": pw})
    assert s == 200, d
    return d["token"], d["record"]["id"]


su, _ = login("_superusers", SU_EMAIL, SU_PASS)
for email, role in [("admin@test.local", "admin"), ("member@test.local", "member")]:
    call("POST", "/api/collections/users/records", su,
         {"email": email, "password": "password123", "passwordConfirm": "password123", "role": role, "emailVisibility": True})
admin, admin_id = login("users", "admin@test.local", "password123")
member, member_id = login("users", "member@test.local", "password123")

# nobody gets in without logging in, and no self sign-up
assert call("GET", "/api/collections/inventory/records")[1]["items"] == []
assert call("POST", "/api/collections/users/records", body={"email": "x@x.x", "password": "password123", "passwordConfirm": "password123"})[0] != 200

# members can't promote themselves or touch inventory directly
assert call("PATCH", f"/api/collections/users/records/{member_id}", member, {"role": "admin"})[0] != 200
assert call("POST", "/api/collections/inventory/records", member, {"name": "x"})[0] != 200

s, item = call("POST", "/api/collections/inventory/records", admin,
               {"name": "M3 screw", "department": "Mechanical", "total_quantity": 5, "available_quantity": 5})
assert s == 200, item
assert call("PATCH", f"/api/collections/inventory/records/{item['id']}", member, {"available_quantity": 99})[0] != 200


def log(action, qty, user=member_id):
    return call("POST", "/api/collections/inventory_logs/records", member,
                {"item": item["id"], "user": user, "quantity": qty, "action": action})[0]


def available():
    return call("GET", f"/api/collections/inventory/records/{item['id']}", admin)[1]["available_quantity"]


assert log("Checked Out", 3) == 200 and available() == 2
assert log("Checked Out", 3) == 400 and available() == 2   # more than available
assert log("Damaged", 1) == 200 and available() == 1
assert log("Returned", 5) == 400 and available() == 1      # above total
assert log("Returned", 4) == 200 and available() == 5
assert log("Checked Out", 1, user=admin_id) != 200 and available() == 5  # can't log as someone else
assert call("GET", "/api/collections/inventory_logs/records", member)[1]["items"] == []  # ledger is admin-only
assert len(call("GET", "/api/collections/inventory_logs/records", admin)[1]["items"]) == 3

# requests: members create Pending only, see only their own, can't change status
body = {"requested_by": member_id, "item_name": "Arduino", "quantity": 1, "department": "Avionics", "justification": "x"}
assert call("POST", "/api/collections/procurement_requests/records", member, {**body, "status": "Approved"})[0] != 200
s, req = call("POST", "/api/collections/procurement_requests/records", member, {**body, "status": "Pending"})
assert s == 200, req
assert call("PATCH", f"/api/collections/procurement_requests/records/{req['id']}", member, {"status": "Approved"})[0] != 200
assert call("PATCH", f"/api/collections/procurement_requests/records/{req['id']}", admin, {"status": "Approved"})[0] == 200
call("POST", "/api/collections/procurement_requests/records", admin, {**body, "requested_by": admin_id, "status": "Pending"})
assert len(call("GET", "/api/collections/procurement_requests/records", member)[1]["items"]) == 1
assert len(call("GET", "/api/collections/procurement_requests/records", admin)[1]["items"]) == 2

# progress reports: can't post as someone else; admins delete
assert call("POST", "/api/collections/progress_reports/records", member, {"user_id": admin_id, "tasks_completed": "x"})[0] != 200
s, rep = call("POST", "/api/collections/progress_reports/records", member, {"user_id": member_id, "tasks_completed": "x"})
assert s == 200, rep
assert call("DELETE", f"/api/collections/progress_reports/records/{rep['id']}", member)[0] != 204
assert call("DELETE", f"/api/collections/progress_reports/records/{rep['id']}", admin)[0] == 204

print("all server checks passed")
