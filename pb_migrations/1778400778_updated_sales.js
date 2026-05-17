/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("yssn6xwhhlq7230")

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "qjagqvdn",
    "name": "payment_reference",
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
  const collection = dao.findCollectionByNameOrId("yssn6xwhhlq7230")

  // remove
  collection.schema.removeField("qjagqvdn")

  return dao.saveCollection(collection)
})
