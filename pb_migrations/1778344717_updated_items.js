/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("qqg19utk3c8milx")

  collection.updateRule = "@request.auth.role = \"admin\""

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("qqg19utk3c8milx")

  collection.updateRule = "1 = 2"

  return dao.saveCollection(collection)
})
