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
assert log("Returned", 4) == 400 and available() == 1      # member only has 3 out (1 was reported damaged separately)
assert log("Returned", 3) == 200 and available() == 4
assert log("Returned", 1) == 400 and available() == 4      # nothing left out
assert log("Checked Out", 1, user=admin_id) != 200 and available() == 4  # can't log as someone else
# members see only their own ledger entries; admins see all
call("POST", "/api/collections/inventory_logs/records", admin,
     {"item": item["id"], "user": admin_id, "quantity": 1, "action": "Checked Out"})
mine = call("GET", "/api/collections/inventory_logs/records", member)[1]["items"]
assert len(mine) == 3 and all(l["user"] == member_id for l in mine), mine
assert len(call("GET", "/api/collections/inventory_logs/records", admin)[1]["items"]) == 4
assert log("Returned", 1, user=admin_id) == 400  # can't return someone else's checkout either
def admin_log(action, qty, **extra):
    return call("POST", "/api/collections/inventory_logs/records", admin,
                {"item": item["id"], "user": admin_id, "quantity": qty, "action": action, **extra})


assert admin_log("Returned", 2)[0] == 400 and available() == 3   # returns are per person, admins too
assert log("Restocked", 1) == 403 and available() == 3           # members can't restock
s, r = admin_log("Restocked", 2, batch="tag123")                  # admins can, recorded as Restocked
assert s == 200 and r["action"] == "Restocked" and r["batch"] == "tag123" and available() == 5
assert admin_log("Restocked", 1)[0] == 400 and available() == 5  # never above total
s, d = call("POST", "/api/collections/inventory_logs/records", member,
            {"item": item["id"], "user": member_id, "quantity": 1, "action": "Restocked"})
assert s == 403 and "admins" in d["message"], d  # item is full: member still hears it's admin-only

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

# equipment bookings: admins add equipment, no overlapping slots, members cancel only their own
assert call("POST", "/api/collections/equipment/records", member, {"name": "x"})[0] != 200
s, printer = call("POST", "/api/collections/equipment/records", admin, {"name": "3D printer"})
assert s == 200, printer


def book(token, user, start, end):
    return call("POST", "/api/collections/bookings/records", token,
                {"equipment": printer["id"], "user": user, "start": start, "end": end})


s, b1 = book(member, member_id, "2030-01-01 10:00:00.000Z", "2030-01-01 12:00:00.000Z")
assert s == 200, b1
assert book(admin, admin_id, "2030-01-01 11:00:00.000Z", "2030-01-01 13:00:00.000Z")[0] == 400  # overlaps
assert book(admin, admin_id, "2030-01-01 09:00:00.000Z", "2030-01-01 10:30:00.000Z")[0] == 400  # overlaps start
assert book(admin, admin_id, "2030-01-01 13:00:00.000Z", "2030-01-01 12:30:00.000Z")[0] == 400  # ends before start
assert book(member, admin_id, "2030-01-02 10:00:00.000Z", "2030-01-02 11:00:00.000Z")[0] != 200  # as someone else
s, b2 = book(admin, admin_id, "2030-01-01 12:00:00.000Z", "2030-01-01 13:00:00.000Z")  # back-to-back is fine
assert s == 200, b2
assert call("DELETE", f"/api/collections/bookings/records/{b2['id']}", member)[0] != 204
assert call("DELETE", f"/api/collections/bookings/records/{b1['id']}", member)[0] == 204

# bulk checkout: a batch is all-or-nothing, and every line still obeys the rules
s, bolt = call("POST", "/api/collections/inventory/records", admin,
               {"name": "Bolt", "department": "Mechanical", "total_quantity": 10, "available_quantity": 10})
s, nut = call("POST", "/api/collections/inventory/records", admin,
              {"name": "Nut", "department": "Mechanical", "total_quantity": 1, "available_quantity": 1})


def batch(lines, user=member_id):
    reqs = [{"method": "POST", "url": "/api/collections/inventory_logs/records",
             "body": {"item": i["id"], "user": user, "quantity": q, "action": "Checked Out"}} for i, q in lines]
    return call("POST", "/api/batch", member, {"requests": reqs})


def stock(i):
    return call("GET", f"/api/collections/inventory/records/{i['id']}", admin)[1]["available_quantity"]


s, d = batch([(bolt, 4), (nut, 2)])  # nut only has 1
assert s == 400 and "2" not in d["data"]["requests"] and "1" in d["data"]["requests"], d
assert stock(bolt) == 10 and stock(nut) == 1  # nothing applied
assert batch([(bolt, 1)], user=admin_id)[0] == 400 and stock(bolt) == 10  # can't batch as someone else
s, d = call("POST", "/api/batch", member, {"requests": [
    {"method": "PATCH", "url": f"/api/collections/inventory/records/{bolt['id']}", "body": {"available_quantity": 99}}]})
assert s == 400 and stock(bolt) == 10  # can't edit stock directly via batch either
assert batch([(bolt, 4), (nut, 1)])[0] == 200 and stock(bolt) == 6 and stock(nut) == 0

# returning a broken part: leaves the member's hands, doesn't go back on the shelf
s, kit = call("POST", "/api/collections/inventory/records", admin,
              {"name": "Kit", "department": "Avionics", "total_quantity": 5, "available_quantity": 5})


def kit_log(action, qty, **extra):
    return call("POST", "/api/collections/inventory_logs/records", member,
                {"item": kit["id"], "user": member_id, "quantity": qty, "action": action, **extra})


assert kit_log("Checked Out", 3)[0] == 200 and stock(kit) == 2
assert kit_log("Returned Damaged", 1, notes="pin bent")[0] == 200 and stock(kit) == 2  # not back on the shelf
assert kit_log("Returned", 3)[0] == 400                                               # only 2 left out now
assert kit_log("Returned", 2)[0] == 200 and stock(kit) == 4                           # 5 total = 4 shelf + 1 broken
assert kit_log("Returned Damaged", 1)[0] == 400                                       # nothing left out

# photos are private: no file token, no photo
s, logged = call("POST", "/api/collections/inventory_logs/records", member,
                 {"item": kit["id"], "user": member_id, "quantity": 1, "action": "Checked Out"})
coll = call("GET", "/api/collections/inventory_logs", su)[1]
photo_field = [f for f in coll["fields"] if f["name"] == "photo"][0]
assert photo_field["protected"] and photo_field["maxSize"] == 5 * 1024 * 1024, photo_field

print("all server checks passed")
