/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("vws8qzfgnnlds8c")

  collection.listRule = "@request.auth.role = \"admin\" || business_id = @request.auth.business_id"
  collection.createRule = ""

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("vws8qzfgnnlds8c")

  collection.listRule = "business_id = @request.auth.business_id"
  collection.createRule = "1 = 2"

  return dao.saveCollection(collection)
})
