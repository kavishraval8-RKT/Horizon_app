/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_3573984430")

  // update field
  collection.fields.addAt(0, new Field({
    "help": "",
    "hidden": false,
    "id": "select2185290330",
    "maxSelect": 0,
    "name": "department",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "select",
    "values": [
      "Avionics",
      "Mechanical"
    ]
  }))

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_3573984430")

  // update field
  collection.fields.addAt(0, new Field({
    "help": "",
    "hidden": false,
    "id": "select2185290330",
    "maxSelect": 0,
    "name": "Department",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "select",
    "values": [
      "Avionics",
      "Mechanical"
    ]
  }))

  return app.save(collection)
})
