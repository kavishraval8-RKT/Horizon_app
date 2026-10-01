/// <reference path="../pb_data/types.d.ts" />
// emailVisibility is required (admins see who made a request), so switch it on for
// every new user instead of relying on whoever creates the account to remember.
onRecordCreate((e) => {
  e.record.set("emailVisibility", true)
  e.next()
}, "users")
