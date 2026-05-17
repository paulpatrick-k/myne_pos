/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("qqg19utk3c8milx")

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "olqrgeg4",
    "name": "item_type",
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

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "t86ymbhu",
    "name": "parent_bottle_id",
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

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("qqg19utk3c8milx")

  // remove
  collection.schema.removeField("olqrgeg4")

  // remove
  collection.schema.removeField("t86ymbhu")

  // remove
  collection.schema.removeField("hqoy6wox")

  return dao.saveCollection(collection)
})
