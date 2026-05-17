/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const collection = new Collection({
    "id": "lg03401zc8jjipm",
    "created": "2026-05-04 09:19:36.026Z",
    "updated": "2026-05-04 09:19:36.026Z",
    "name": "businesses",
    "type": "base",
    "system": false,
    "schema": [
      {
        "system": false,
        "id": "u9giknpf",
        "name": "business_name",
        "type": "text",
        "required": false,
        "presentable": false,
        "unique": false,
        "options": {
          "min": null,
          "max": null,
          "pattern": ""
        }
      }
    ],
    "indexes": [],
    "listRule": "",
    "viewRule": "",
    "createRule": "",
    "updateRule": "",
    "deleteRule": "",
    "options": {}
  });

  return Dao(db).saveCollection(collection);
}, (db) => {
  const dao = new Dao(db);
  const collection = dao.findCollectionByNameOrId("lg03401zc8jjipm");

  return dao.deleteCollection(collection);
})
