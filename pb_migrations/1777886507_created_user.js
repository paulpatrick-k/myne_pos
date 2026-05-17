/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const collection = new Collection({
    "id": "nto9tl02zo5z6nz",
    "created": "2026-05-04 09:21:47.986Z",
    "updated": "2026-05-04 09:21:47.986Z",
    "name": "user",
    "type": "auth",
    "system": false,
    "schema": [
      {
        "system": false,
        "id": "9i9l7zow",
        "name": "role",
        "type": "select",
        "required": false,
        "presentable": false,
        "unique": false,
        "options": {
          "maxSelect": 1,
          "values": [
            "admin",
            "staff"
          ]
        }
      },
      {
        "system": false,
        "id": "3yxlqh2y",
        "name": "business_id",
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
    "listRule": null,
    "viewRule": null,
    "createRule": null,
    "updateRule": null,
    "deleteRule": null,
    "options": {
      "allowEmailAuth": true,
      "allowOAuth2Auth": true,
      "allowUsernameAuth": true,
      "exceptEmailDomains": null,
      "manageRule": null,
      "minPasswordLength": 8,
      "onlyEmailDomains": null,
      "onlyVerified": false,
      "requireEmail": false
    }
  });

  return Dao(db).saveCollection(collection);
}, (db) => {
  const dao = new Dao(db);
  const collection = dao.findCollectionByNameOrId("nto9tl02zo5z6nz");

  return dao.deleteCollection(collection);
})
