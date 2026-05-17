/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db);
  const collection = dao.findCollectionByNameOrId("sales");

  return dao.deleteCollection(collection);
}, (db) => {
  const collection = new Collection({
    "id": "sales",
    "created": "2026-05-03 19:59:52.902Z",
    "updated": "2026-05-03 19:59:52.902Z",
    "name": "sales",
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
        "id": "user",
        "name": "user",
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
        "id": "items",
        "name": "items",
        "type": "json",
        "required": true,
        "presentable": false,
        "unique": false,
        "options": {
          "maxSize": 0
        }
      },
      {
        "system": false,
        "id": "total_amount",
        "name": "total_amount",
        "type": "number",
        "required": true,
        "presentable": false,
        "unique": false,
        "options": {
          "min": null,
          "max": null,
          "noDecimal": false
        }
      },
      {
        "system": false,
        "id": "payment_method",
        "name": "payment_method",
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
        "id": "receipt_no",
        "name": "receipt_no",
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
        "id": "payment_reference",
        "name": "payment_reference",
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
    "listRule": "business_id = @request.auth.user.business_id",
    "viewRule": "business_id = @request.auth.user.business_id",
    "createRule": "@request.auth.id != \"\" && @request.data.business_id = @request.auth.user.business_id && @request.data.user = @request.auth.id",
    "updateRule": "@request.auth.user.role = \"admin\" && business_id = @request.auth.user.business_id",
    "deleteRule": "@request.auth.user.role = \"admin\" && business_id = @request.auth.user.business_id",
    "options": {}
  });

  return Dao(db).saveCollection(collection);
})
