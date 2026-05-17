/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("nto9tl02zo5z6nz")

  collection.updateRule = "@request.auth.id = id || @request.auth.role = \"admin\""

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("nto9tl02zo5z6nz")

  collection.updateRule = "1 = 2"

  return dao.saveCollection(collection)
})
