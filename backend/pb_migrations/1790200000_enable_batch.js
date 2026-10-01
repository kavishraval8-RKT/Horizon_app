/// <reference path="../pb_data/types.d.ts" />
// Bulk checkout sends every line of a basket as one batch: PocketBase runs the
// whole batch in a single transaction, so either every part is checked out or none is.
// Rules and the stock hook still apply to each line exactly as for a single checkout.
migrate((app) => {
  const settings = app.settings()
  settings.batch.enabled = true
  settings.batch.maxRequests = 20 // basket is capped at 10 parts in the app
  settings.batch.timeout = 10
  app.save(settings)
}, (app) => {
  const settings = app.settings()
  settings.batch.enabled = false
  app.save(settings)
})
