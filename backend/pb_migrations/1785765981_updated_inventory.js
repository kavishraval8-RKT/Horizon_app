/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_3573984430")

  // remove field
  collection.fields.removeById("select2063623452")

  // remove field
  collection.fields.removeById("relation2277536159")

  // remove field
  collection.fields.removeById("file1101547370")

  // remove field
  collection.fields.removeById("text2543575956")

  // add field
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

  // add field
  collection.fields.addAt(3, new Field({
    "help": "",
    "hidden": false,
    "id": "number554441351",
    "max": null,
    "min": null,
    "name": "total_quantity",
    "onlyInt": false,
    "presentable": false,
    "required": false,
    "system": false,
    "type": "number"
  }))

  // add field
  collection.fields.addAt(4, new Field({
    "help": "",
    "hidden": false,
    "id": "number2222581094",
    "max": null,
    "min": null,
    "name": "available_quantity",
    "onlyInt": false,
    "presentable": false,
    "required": false,
    "system": false,
    "type": "number"
  }))

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_3573984430")

  // add field
  collection.fields.addAt(2, new Field({
    "help": "",
    "hidden": false,
    "id": "select2063623452",
    "maxSelect": 1,
    "name": "status",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "select",
    "values": [
      "Available",
      "Checked Out",
      "Damaged"
    ]
  }))

  // add field
  collection.fields.addAt(3, new Field({
    "cascadeDelete": false,
    "collectionId": "_pb_users_auth_",
    "help": "",
    "hidden": false,
    "id": "relation2277536159",
    "maxSelect": 0,
    "minSelect": 0,
    "name": "checked_out_by",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "relation"
  }))

  // add field
  collection.fields.addAt(4, new Field({
    "help": "",
    "hidden": false,
    "id": "file1101547370",
    "maxSelect": 0,
    "maxSize": 0,
    "mimeTypes": null,
    "name": "photo_proof",
    "presentable": false,
    "protected": false,
    "required": false,
    "system": false,
    "thumbs": null,
    "type": "file"
  }))

  // add field
  collection.fields.addAt(5, new Field({
    "autogeneratePattern": "",
    "help": "",
    "hidden": false,
    "id": "text2543575956",
    "max": 0,
    "min": 0,
    "name": "damage_notes",
    "pattern": "",
    "presentable": false,
    "primaryKey": false,
    "required": false,
    "system": false,
    "type": "text"
  }))

  // remove field
  collection.fields.removeById("select2185290330")

  // remove field
  collection.fields.removeById("number554441351")

  // remove field
  collection.fields.removeById("number2222581094")

  return app.save(collection)
})
