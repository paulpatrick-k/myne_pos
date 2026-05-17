/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db);
  const collection = dao.findCollectionByNameOrId("audit_logs");

  return dao.deleteCollection(collection);
}, (db) => {
  const collection = new Collection({
    "id": "audit_logs",
    "created": "2026-05-03 19:59:52.902Z",
    "updated": "2026-05-03 19:59:52.902Z",
    "name": "audit_logs",
    "type": "base",
    "system": false,
    "schema": [
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
      },
      {
        "system": false,
        "id": "user_id",
        "name": "user_id",
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
        "id": "user_email",
        "name": "user_email",
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
        "id": "action",
        "name": "action",
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
        "id": "details",
        "name": "details",
        "type": "json",
        "required": false,
        "presentable": false,
        "unique": false,
        "options": {
          "maxSize": 0
        }
      }
    ],
    "indexes": [],
    "listRule": "(@request.auth.id != \"\" && user_id = @request.auth.id && business_id = @request.auth.user.business_id) || (@request.auth.user.role = \"admin\" && business_id = @request.auth.user.business_id)",
    "viewRule": "(@request.auth.id != \"\" && user_id = @request.auth.id && business_id = @request.auth.user.business_id) || (@request.auth.user.role = \"admin\" && business_id = @request.auth.user.business_id)",
    "createRule": "@request.auth.id != \"\" && @request.data.user_id = @request.auth.id && @request.data.business_id = @request.auth.user.business_id",
    "updateRule": "@request.auth.user.role = \"admin\" && business_id = @request.auth.user.business_id",
    "deleteRule": "@request.auth.user.role = \"admin\" && business_id = @request.auth.user.business_id",
    "options": {}
  });

  return Dao(db).saveCollection(collection);
})
