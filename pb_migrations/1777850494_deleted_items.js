/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db);
  const collection = dao.findCollectionByNameOrId("items");

  return dao.deleteCollection(collection);
}, (db) => {
  const collection = new Collection({
    "id": "items",
    "created": "2026-05-03 19:59:52.902Z",
    "updated": "2026-05-03 19:59:52.902Z",
    "name": "items",
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
        "id": "name",
        "name": "name",
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
        "id": "price",
        "name": "price",
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
        "id": "stock_qty",
        "name": "stock_qty",
        "type": "number",
        "required": true,
        "presentable": false,
        "unique": false,
        "options": {
          "min": null,
          "max": null,
          "noDecimal": false
        }
      }
    ],
    "indexes": [],
    "listRule": "business_id = @request.auth.user.business_id",
    "viewRule": "business_id = @request.auth.user.business_id",
    "createRule": "@request.auth.user.role = \"admin\" && business_id = @request.auth.user.business_id",
    "updateRule": "@request.auth.user.role = \"admin\" && business_id = @request.auth.user.business_id",
    "deleteRule": "@request.auth.user.role = \"admin\" && business_id = @request.auth.user.business_id",
    "options": {}
  });

  return Dao(db).saveCollection(collection);
})
