/// <reference path="../pb_data/types.d.ts" />
// - "Restocked": an admin putting stock back when nobody had it out (found, miscount).
//   Kept separate from "Returned" so the ledger never shows a correction as someone's return.
// - "batch": a shared tag on every line of one bulk check-out/return, so the ledger
//   can show the whole basket as one entry.
migrate((app) => {
  const c = app.findCollectionByNameOrId("inventory_logs")
  const action = c.fields.getByName("action")
  action.values = ["Checked Out", "Returned", "Damaged", "Restocked"]
  c.fields.add(new TextField({ name: "batch", max: 32 }))
  app.save(c)
}, (app) => {
  const c = app.findCollectionByNameOrId("inventory_logs")
  c.fields.getByName("action").values = ["Checked Out", "Returned", "Damaged"]
  c.fields.removeByName("batch")
  app.save(c)
})
