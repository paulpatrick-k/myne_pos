/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("yssn6xwhhlq7230")

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "0plkr3d1",
    "name": "kra_status",
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
    "id": "4rcazxrw",
    "name": "kra_invoice_id",
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
    "id": "gozhdnsy",
    "name": "kra_qr_code_url",
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

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("yssn6xwhhlq7230")

  // remove
  collection.schema.removeField("0plkr3d1")

  // remove
  collection.schema.removeField("4rcazxrw")

  // remove
  collection.schema.removeField("gozhdnsy")

  // remove
  collection.schema.removeField("jvgqm4pf")

  return dao.saveCollection(collection)
})
