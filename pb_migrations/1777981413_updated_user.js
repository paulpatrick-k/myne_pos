/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("nto9tl02zo5z6nz")

  collection.listRule = "@request.auth.role = \"admin\""
  collection.viewRule = "@request.auth.id = id || @request.auth.role = \"admin\""
  collection.createRule = "1 = 2"
  collection.updateRule = "1 = 2"
  collection.deleteRule = "1 = 2"

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("nto9tl02zo5z6nz")

  collection.listRule = null
  collection.viewRule = null
  collection.createRule = null
  collection.updateRule = null
  collection.deleteRule = null

  return dao.saveCollection(collection)
})
