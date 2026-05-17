/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("yssn6xwhhlq7230")

  collection.listRule = "business_id = @request.auth.business_id"
  collection.viewRule = "business_id = @request.auth.business_id"
  collection.createRule = "1 = 2"
  collection.updateRule = "1 = 2"
  collection.deleteRule = "1 = 2"

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "uemail",
    "name": "user_email",
    "type": "text",
    "required": true,
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
    "id": "rcptno",
    "name": "receipt_no",
    "type": "text",
    "required": true,
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

  collection.listRule = null
  collection.viewRule = null
  collection.createRule = ""
  collection.updateRule = ""
  collection.deleteRule = ""

  // remove
  collection.schema.removeField("uemail")

  // remove
  collection.schema.removeField("rcptno")

  return dao.saveCollection(collection)
})
