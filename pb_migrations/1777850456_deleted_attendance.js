/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db);
  const collection = dao.findCollectionByNameOrId("attendance");

  return dao.deleteCollection(collection);
}, (db) => {
  const collection = new Collection({
    "id": "attendance",
    "created": "2026-05-03 19:59:52.902Z",
    "updated": "2026-05-03 19:59:52.902Z",
    "name": "attendance",
    "type": "base",
    "system": false,
    "schema": [
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
        "id": "checkin_time",
        "name": "checkin_time",
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
        "id": "checkout_time",
        "name": "checkout_time",
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
    "listRule": "(@request.auth.id != \"\" && user_id = @request.auth.id && business_id = @request.auth.user.business_id) || (@request.auth.user.role = \"admin\" && business_id = @request.auth.user.business_id)",
    "viewRule": "(@request.auth.id != \"\" && user_id = @request.auth.id && business_id = @request.auth.user.business_id) || (@request.auth.user.role = \"admin\" && business_id = @request.auth.user.business_id)",
    "createRule": "@request.auth.id != \"\" && @request.data.user_id = @request.auth.id && @request.data.business_id = @request.auth.user.business_id",
    "updateRule": "(@request.auth.id != \"\" && user_id = @request.auth.id && business_id = @request.auth.user.business_id) || (@request.auth.user.role = \"admin\" && business_id = @request.auth.user.business_id)",
    "deleteRule": "@request.auth.user.role = \"admin\" && business_id = @request.auth.user.business_id",
    "options": {}
  });

  return Dao(db).saveCollection(collection);
})
