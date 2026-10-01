/// <reference path="../pb_data/types.d.ts" />
// - "Returned Damaged": a member hands back a part they had out, but it's broken.
//   It leaves their hands (counts as a return) without going back on the shelf.
// - Ledger photos: private (only logged-in members can view them), images only,
//   5 MB max, with a small thumbnail for lists.
// - Daily 3am backup of database + photos, keeping the last 7.
migrate((app) => {
  const c = app.findCollectionByNameOrId("inventory_logs")
  c.fields.getByName("action").values = ["Checked Out", "Returned", "Damaged", "Restocked", "Returned Damaged"]
  const photo = c.fields.getByName("photo")
  photo.protected = true
  photo.maxSelect = 1
  photo.maxSize = 5 * 1024 * 1024
  photo.mimeTypes = ["image/jpeg", "image/png", "image/webp"]
  photo.thumbs = ["200x200"]
  app.save(c)

  const settings = app.settings()
  settings.backups.cron = "0 3 * * *"
  settings.backups.cronMaxKeep = 7
  app.save(settings)
}, (app) => {
  const c = app.findCollectionByNameOrId("inventory_logs")
  c.fields.getByName("action").values = ["Checked Out", "Returned", "Damaged", "Restocked"]
  c.fields.getByName("photo").protected = false
  app.save(c)
  const settings = app.settings()
  settings.backups.cron = ""
  app.save(settings)
})
