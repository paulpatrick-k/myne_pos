/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("lg03401zc8jjipm")

  // add
  collection.schema.addField(new SchemaField({
    "system": false,
    "id": "emqxdupy",
    "name": "country",
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
    "id": "6k9kmwqm",
    "name": "currency_code",
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
  const collection = dao.findCollectionByNameOrId("lg03401zc8jjipm")

  // remove
  collection.schema.removeField("emqxdupy")

  // remove
  collection.schema.removeField("6k9kmwqm")

  return dao.saveCollection(collection)
})
