/// <reference path="../pb_data/types.d.ts" />
// Every inventory_logs insert adjusts the item's available_quantity in the same
// DB transaction, so the ledger and the counts can't drift apart.
onRecordCreateExecute((e) => {
  e.app.runInTransaction((txApp) => {
    const item = txApp.findRecordById("inventory", e.record.getString("item"))
    const qty = e.record.getInt("quantity")
    const action = e.record.getString("action")
    const available = item.getInt("available_quantity")
    const total = item.getInt("total_quantity")

    if (qty <= 0) throw new BadRequestError("Quantity must be positive.")

    // The create rule guarantees `user` is whoever is making the request.
    const userId = e.record.getString("user")

    // Restock: an admin putting back stock nobody had out (found, miscount).
    // Checked before the stock maths so a member gets the real reason.
    if (action === "Restocked") {
      if (txApp.findRecordById("users", userId).getString("role") !== "admin") {
        throw new ForbiddenError("Only admins can restock.")
      }
    }

    let next
    if (action === "Checked Out" || action === "Damaged") next = available - qty
    else if (action === "Returned" || action === "Restocked") next = available + qty
    else if (action === "Returned Damaged") next = available // back from the member, but broken: not on the shelf
    else throw new BadRequestError("Unknown action.")

    if (next < 0) throw new BadRequestError(`Only ${available} available.`)
    if (next > total) throw new BadRequestError(`Only ${total - available} more fit (total is ${total}).`)

    // Return (good or damaged): anyone, admins included, can only return what they
    // themselves have out (their check-outs minus their returns of either kind).
    if (action === "Returned" || action === "Returned Damaged") {
      // Walk this person's history for the part in time order, never letting the
      // balance go below zero: a return can only cancel what was out at that moment.
      // (Before per-person returns existed, admins could "return" stock nobody had
      // out; a plain sum turned those into credit that hid later check-outs.)
      const rows = arrayOf(new DynamicModel({ action: "", quantity: 0 }))
      txApp.db()
        .newQuery(
          "SELECT action, quantity FROM inventory_logs WHERE item = {:item} AND user = {:user} " +
          "ORDER BY created, rowid")
        .bind({ item: item.id, user: userId })
        .all(rows)
      let out = 0
      for (const r of rows) {
        if (r.action === "Checked Out") out += r.quantity
        else if (r.action === "Returned" || r.action === "Returned Damaged") out = Math.max(0, out - r.quantity)
      }
      if (qty > out) {
        throw new BadRequestError(out > 0
          ? `You only have ${out} of these checked out.`
          : "You don't have any of these checked out.")
      }
    }

    item.set("available_quantity", next)
    txApp.save(item)

    e.app = txApp
    e.next()
  })
}, "inventory_logs")
