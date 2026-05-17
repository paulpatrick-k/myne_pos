/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("qqg19utk3c8milx")

  collection.listRule = "business_id = @request.auth.business_id"
  collection.viewRule = "business_id = @request.auth.business_id"
  collection.createRule = "1 = 2"
  collection.updateRule = "1 = 2"
  collection.deleteRule = "1 = 2"

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "custdata",
    "name": "custom_data",
    "type": "json",
    "required": false,
    "presentable": false,
    "unique": false,
    "options": {
      "maxSize": 2000000
    }
  }))

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("qqg19utk3c8milx")

  collection.listRule = null
  collection.viewRule = null
  collection.createRule = ""
  collection.updateRule = ""
  collection.deleteRule = ""

  // remove
  collection.schema.removeField("custdata")

  return dao.saveCollection(collection)
})
