/// <reference path="../pb_data/types.d.ts" />
// Progress-report emails, Monday to Friday. The server runs on UTC:
//   15:30 UTC = 21:00 India time  -> "due by 10 pm" reminder
//   16:30 UTC = 22:00 India time  -> "missed" notice + admin summary
// Logic lives in reminders.js (hook handlers can't share top-level code, so each requires it).

cronAdd("progress-reminder", "30 15 * * 1-5", () => {
  require(`${__hooks}/reminders.js`).run($app, "reminder", true)
})

cronAdd("progress-missed", "30 16 * * 1-5", () => {
  require(`${__hooks}/reminders.js`).run($app, "missed", true)
})

// Superusers only: see who would be emailed right now, or send for real to test the
// mail setup.  POST /api/horizon/progress-reminders?kind=reminder|missed&send=1
routerAdd("POST", "/api/horizon/progress-reminders", (e) => {
  const kind = e.request.url.query().get("kind") === "missed" ? "missed" : "reminder"
  const send = e.request.url.query().get("send") === "1"
  return e.json(200, require(`${__hooks}/reminders.js`).run($app, kind, send))
}, $apis.requireSuperuserAuth())
