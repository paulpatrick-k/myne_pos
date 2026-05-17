/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("yssn6xwhhlq7230")

  // remove
  collection.schema.removeField("jvgqm4pf")

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "hgyvteyn",
    "name": "kra_sync_attempts",
    "type": "number",
    "required": false,
    "presentable": false,
    "unique": false,
    "options": {
      "min": 0,
      "max": 5,
      "noDecimal": true
    }
  }))

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("yssn6xwhhlq7230")

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "jvgqm4pf",
    "name": "kra_sync_attempts",
    "type": "text",
    "required": false,
    "presentable": false,
    "unique": false,
    "options": {
      "min": 0,
      "max": 5,
      "pattern": ""
    }
  }))

  // remove
  collection.schema.removeField("hgyvteyn")

  return dao.saveCollection(collection)
})
