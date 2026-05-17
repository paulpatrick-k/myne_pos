/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("qqg19utk3c8milx")

  // remove
  collection.schema.removeField("hqoy6wox")

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "e9y1zn1l",
    "name": "shots_per_bottle",
    "type": "number",
    "required": false,
    "presentable": false,
    "unique": false,
    "options": {
      "min": null,
      "max": null,
      "noDecimal": false
    }
  }))

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("qqg19utk3c8milx")

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "hqoy6wox",
    "name": "shots_per_bottle",
    "type": "text",
    "required": false,
    "presentable": false,
    "unique": false,
    "options": {
      "min": null,
      "max": null,
      "pattern": ""
    }
  }))

  // remove
  collection.schema.removeField("e9y1zn1l")

  return dao.saveCollection(collection)
})
