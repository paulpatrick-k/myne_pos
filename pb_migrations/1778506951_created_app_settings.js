/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const collection = new Collection({
    "id": "lw0kg9ps0jb5itp",
    "created": "2026-05-11 13:42:31.440Z",
    "updated": "2026-05-11 13:42:31.440Z",
    "name": "app_settings",
    "type": "base",
    "system": false,
    "schema": [
      {
        "system": false,
        "id": "8tt5nzat",
        "name": "key",
        "type": "text",
        "required": true,
        "presentable": false,
        "unique": false,
        "options": {
          "min": null,
          "max": null,
          "pattern": ""
        }
      },
      {
        "system": false,
        "id": "qifzuqzt",
        "name": "value",
        "type": "text",
        "required": true,
        "presentable": false,
        "unique": false,
        "options": {
          "min": null,
          "max": null,
          "pattern": ""
        }
      }
    ],
    "indexes": [
      "CREATE UNIQUE INDEX `idx_g6EF5jK` ON `app_settings` (`key`)"
    ],
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
  const collection = dao.findCollectionByNameOrId("lw0kg9ps0jb5itp");

  return dao.deleteCollection(collection);
})
