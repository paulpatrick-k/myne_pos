/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db);
  const collection = dao.findCollectionByNameOrId("user");

  return dao.deleteCollection(collection);
}, (db) => {
  const collection = new Collection({
    "id": "user",
    "created": "2026-05-03 19:59:52.901Z",
    "updated": "2026-05-03 19:59:52.901Z",
    "name": "user",
    "type": "auth",
    "system": false,
    "schema": [
      {
        "system": false,
        "id": "role",
        "name": "role",
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
        "id": "business_id",
        "name": "business_id",
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
    "indexes": [],
    "listRule": "business_id = @request.auth.user.business_id",
    "viewRule": "id = @request.auth.id || business_id = @request.auth.user.business_id",
    "createRule": "",
    "updateRule": "id = @request.auth.id || (@request.auth.user.role = \"admin\" && business_id = @request.auth.user.business_id)",
    "deleteRule": "@request.auth.user.role = \"admin\" && business_id = @request.auth.user.business_id",
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
})
