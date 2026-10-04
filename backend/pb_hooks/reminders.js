// Progress-report reminder emails. Loaded with require() from reminders.pb.js
// (plain .js, so PocketBase doesn't run it as a hooks file on its own).
//
// Reports are due by 22:00 India time, Monday to Friday. Members (not admins) who
// haven't filed one since midnight get:
//   "reminder" at 21:00  - due in an hour
//   "missed"   at 22:00  - missed today's report; admins also get a summary
// Email goes out through the SMTP settings in the dashboard (Settings > Mail settings,
// e.g. Resend's SMTP). Nothing is sent until SMTP is enabled there.

const IST_OFFSET_MS = 330 * 60 * 1000 // UTC+5:30

/** Midnight today in India, as PocketBase's stored UTC format ("2026-10-04 18:30:00.000Z"). */
function todayStartUtc() {
  const ist = new Date(Date.now() + IST_OFFSET_MS)
  const midnight = Date.UTC(ist.getUTCFullYear(), ist.getUTCMonth(), ist.getUTCDate()) - IST_OFFSET_MS
  return new Date(midnight).toISOString().replace("T", " ")
}

function todayLabel() {
  const ist = new Date(Date.now() + IST_OFFSET_MS)
  const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
  const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
  return `${days[ist.getUTCDay()]} ${ist.getUTCDate()} ${months[ist.getUTCMonth()]}`
}

function esc(s) {
  return String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c])
}

function page(title, body) {
  return `<div style="font-family:Arial,sans-serif;max-width:480px;color:#161614">
<div style="width:32px;height:3px;background:#E0480E;margin-bottom:16px"></div>
<h2 style="margin:0 0 12px;font-size:20px">${title}</h2>${body}
<p style="color:#6E6A62;font-size:12px;margin-top:24px">Horizon · Rocketry Team Portal. This is an automatic message; replies aren't read.</p></div>`
}

/**
 * kind: "reminder" | "missed". send=false only reports who would be emailed.
 * Returns { kind, date, notFiled: [{name,email}], admins, sent, failed, skipped }.
 */
function run(app, kind, send) {
  const start = todayStartUtc()
  const users = app.findAllRecords("users")
  const isAdmin = (u) => u.getString("role") === "admin"
  const nameOf = (u) => u.getString("name") || u.email()

  const notFiled = []
  for (const u of users) {
    if (isAdmin(u) || !u.email()) continue
    const filed = app.findRecordsByFilter(
      "progress_reports", "user_id = {:u} && created >= {:start}", "", 1, 0, { u: u.id, start },
    ).length > 0
    if (!filed) notFiled.push(u)
  }
  const admins = users.filter((u) => isAdmin(u) && u.email())

  const result = {
    kind,
    date: todayLabel(),
    since: start,
    notFiled: notFiled.map((u) => ({ name: nameOf(u), email: u.email() })),
    admins: admins.map((u) => u.email()),
    sent: 0,
    failed: [],
    skipped: "",
  }
  if (!send) return result

  const settings = app.settings()
  if (!settings.smtp.enabled) {
    result.skipped = "Email isn't set up yet (dashboard > Settings > Mail settings)."
    console.log("progress reminders:", result.skipped)
    return result
  }
  const from = { address: settings.meta.senderAddress, name: settings.meta.senderName || "Horizon" }

  function mail(to, subject, html) {
    try {
      app.newMailClient().send(new MailerMessage({ from, to: [{ address: to }], subject, html }))
      result.sent++
    } catch (err) {
      result.failed.push(`${to}: ${err}`)
    }
  }

  for (const u of notFiled) {
    const hi = `<p>Hi ${esc(nameOf(u))},</p>`
    if (kind === "reminder") {
      mail(u.email(), "Reminder: progress report due by 10 pm",
        page("Your progress report is due by 10 pm",
          `${hi}<p>You haven't filed today's progress report yet (${result.date}).</p>
<p>Open <b>Horizon → Progress → +</b> and add what you worked on and any blockers. It takes a minute.</p>`))
    } else {
      mail(u.email(), "You missed today's progress report",
        page("Today's progress report was missed",
          `${hi}<p>No progress report was filed for ${result.date}. Please file one tomorrow,
and let an admin know if something is blocking you.</p>`))
    }
  }

  if (kind === "missed") {
    const list = notFiled.length
      ? `<p>${notFiled.length} member${notFiled.length === 1 ? "" : "s"} didn't file a report:</p><ul>` +
        notFiled.map((u) => `<li>${esc(nameOf(u))} <span style="color:#6E6A62">(${esc(u.email())})</span></li>`).join("") +
        "</ul>"
      : "<p>Everyone filed today. 🎉</p>"
    for (const a of admins) {
      mail(a.email(), `Progress reports ${result.date}: ${notFiled.length ? notFiled.length + " missed" : "all filed"}`,
        page(`Progress reports · ${result.date}`, list))
    }
  }

  console.log(`progress reminders (${kind}): sent ${result.sent}, failed ${result.failed.length}`)
  return result
}

module.exports = { run, todayStartUtc }
