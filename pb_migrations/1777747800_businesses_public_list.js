/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const dao = new Dao(db);
  const businesses = dao.findCollectionByNameOrId("businesses");
  if (!businesses) {
    throw new Error("Collection businesses not found");
  }

  businesses.listRule = "";
  businesses.viewRule = "";
  return dao.saveCollection(businesses);
}, (db) => {
  const dao = new Dao(db);
  const businesses = dao.findCollectionByNameOrId("businesses");
  if (!businesses) {
    throw new Error("Collection businesses not found");
  }

  businesses.listRule = "id = @request.auth.user.business_id";
  businesses.viewRule = "id = @request.auth.user.business_id";
  return dao.saveCollection(businesses);
})
