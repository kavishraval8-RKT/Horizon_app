/// <reference path="../pb_data/types.d.ts" />
// Services page: shared equipment (3D printer, drill press, ...) and time-slot bookings.
// Overlapping bookings are rejected in pb_hooks/bookings.pb.js.
const AUTH = '@request.auth.id != ""'
const ADMIN = '@request.auth.role = "admin"'
const timestamps = [
  { name: "created", type: "autodate", onCreate: true, onUpdate: false },
  { name: "updated", type: "autodate", onCreate: true, onUpdate: true },
]

migrate((app) => {
  const equipment = new Collection({
    type: "base",
    name: "equipment",
    listRule: AUTH,
    viewRule: AUTH,
    createRule: ADMIN,
    updateRule: ADMIN,
    deleteRule: ADMIN,
    fields: [
      { name: "name", type: "text", required: true },
      { name: "notes", type: "text" },
      ...timestamps,
    ],
  })
  app.save(equipment)

  app.save(new Collection({
    type: "base",
    name: "bookings",
    listRule: AUTH, // everyone sees the schedule
    viewRule: AUTH,
    createRule: `${AUTH} && @request.body.user = @request.auth.id`,
    updateRule: null,
    deleteRule: `user = @request.auth.id || ${ADMIN}`,
    fields: [
      { name: "equipment", type: "relation", collectionId: equipment.id, maxSelect: 1, required: true, cascadeDelete: true },
      { name: "user", type: "relation", collectionId: "_pb_users_auth_", maxSelect: 1, required: true, cascadeDelete: true },
      { name: "start", type: "date", required: true },
      { name: "end", type: "date", required: true },
      { name: "purpose", type: "text" },
      ...timestamps,
    ],
    indexes: ["CREATE INDEX idx_bookings_equipment_start ON bookings (equipment, start)"],
  }))
}, (app) => {
  app.delete(app.findCollectionByNameOrId("bookings"))
  app.delete(app.findCollectionByNameOrId("equipment"))
})
