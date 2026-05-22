/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("lg03401zc8jjipm")

  collection.createRule = "1 = 1"

  return dao.saveCollection(collection)
}, (db) => {
  const dao = new Dao(db)
  const collection = dao.findCollectionByNameOrId("lg03401zc8jjipm")

  collection.createRule = "1 = 2"

  return dao.saveCollection(collection)
})
