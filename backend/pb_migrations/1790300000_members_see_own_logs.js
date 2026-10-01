/// <reference path="../pb_data/types.d.ts" />
// "Return parts" works out what a member has checked out from their own ledger
// entries, so members may read their own inventory_logs (never anyone else's).
// Admins still see everything.
migrate((app) => {
  const c = app.findCollectionByNameOrId("inventory_logs")
  unmarshal({
    listRule: '@request.auth.id != "" && (user = @request.auth.id || @request.auth.role = "admin")',
    viewRule: '@request.auth.id != "" && (user = @request.auth.id || @request.auth.role = "admin")',
  }, c)
  app.save(c)
}, (app) => {
  const c = app.findCollectionByNameOrId("inventory_logs")
  unmarshal({ listRule: '@request.auth.role = "admin"', viewRule: '@request.auth.role = "admin"' }, c)
  app.save(c)
})
