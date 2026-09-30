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

    item.set("available_quantity", next)
    txApp.save(item)

    e.app = txApp
    e.next()
  })
}, "inventory_logs")
