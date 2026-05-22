/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("lg03401zc8jjipm")

  collection.listRule = "@request.auth.id != \"\" && id = @request.auth.business_id"
  collection.viewRule = "@request.auth.id != \"\" && id = @request.auth.business_id"
  collection.createRule = ""
  collection.updateRule = ""
  collection.deleteRule = ""

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("lg03401zc8jjipm")

  collection.listRule = "@request.auth.id != null || unique_code != \"\" "
  collection.viewRule = ""
  collection.createRule = "1 = 1"
  collection.updateRule = "1 = 2"
  collection.deleteRule = "1 = 2"

  return dao.saveCollection(collection)
})
