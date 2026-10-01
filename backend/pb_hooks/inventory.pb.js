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

    let next
    if (action === "Checked Out" || action === "Damaged") next = available - qty
    else if (action === "Returned") next = available + qty
    else throw new BadRequestError("Unknown action.")

    if (next < 0) throw new BadRequestError(`Only ${available} available.`)
    if (next > total) throw new BadRequestError(`Only ${total - available} can be returned.`)

    // Members can only return what they themselves have out (checked out minus returned).
    // Admins may return beyond that to correct stock.
    if (action === "Returned") {
      const userId = e.record.getString("user")
      const user = txApp.findRecordById("users", userId)
      if (user.getString("role") !== "admin") {
        const out = new DynamicModel({ n: 0 })
        txApp.db()
          .newQuery(
            "SELECT COALESCE(SUM(CASE WHEN action = 'Checked Out' THEN quantity " +
            "WHEN action = 'Returned' THEN -quantity ELSE 0 END), 0) AS n " +
            "FROM inventory_logs WHERE item = {:item} AND user = {:user}")
          .bind({ item: item.id, user: userId })
          .one(out)
        if (qty > out.n) {
          throw new BadRequestError(out.n > 0
            ? `You only have ${out.n} of these checked out.`
            : "You don't have any of these checked out.")
        }
      }
    }

    item.set("available_quantity", next)
    txApp.save(item)

    e.app = txApp
    e.next()
  })
}, "inventory_logs")
