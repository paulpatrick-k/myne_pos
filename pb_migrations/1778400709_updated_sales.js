/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("yssn6xwhhlq7230")

  collection.createRule = "@request.auth.id != null"

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("yssn6xwhhlq7230")

  collection.createRule = "1 = 2"

  return dao.saveCollection(collection)
})
