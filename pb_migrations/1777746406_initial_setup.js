/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
  const collections = [
    new Collection({
      id: "businesses",
      name: "businesses",
      type: "base",
      system: false,
      schema: [
        {
          id: "business_name",
          name: "business_name",
          type: "text",
          system: false,
          required: true,
          presentable: false,
          unique: false,
          options: {
            min: null,
            max: null,
            pattern: ""
          }
        },
        {
          id: "email",
          name: "email",
          type: "text",
          system: false,
          required: true,
          presentable: false,
          unique: false,
          options: {
            min: null,
            max: null,
            pattern: ""
          }
        },
        {
          id: "phone",
          name: "phone",
          type: "text",
          system: false,
          required: true,
          presentable: false,
          unique: false,
          options: {
            min: null,
            max: null,
            pattern: ""
          }
        },
        {
          id: "address",
          name: "address",
          type: "text",
          system: false,
          required: true,
          presentable: false,
          unique: false,
          options: {
            min: null,
            max: null,
            pattern: ""
          }
        },
        {
          id: "category",
          name: "category",
          type: "text",
          system: false,
          required: true,
          presentable: false,
          unique: false,
          options: {
            min: null,
            max: null,
            pattern: ""
          }
        },
        {
          id: "unique_code",
          name: "unique_code",
          type: "text",
          system: false,
          required: true,
          presentable: false,
          unique: false,
          options: {
            min: null,
            max: null,
            pattern: ""
          }
        },
        {
          id: "trial_start",
          name: "trial_start",
          type: "text",
          system: false,
          required: false,
          presentable: false,
          unique: false,
          options: {
            min: null,
            max: null,
            pattern: ""
          }
        },
        {
          id: "trial_end",
          name: "trial_end",
          type: "text",
          system: false,
          required: false,
          presentable: false,
          unique: false,
          options: {
            min: null,
            max: null,
            pattern: ""
          }
        },
        {
          id: "subscription_active",
          name: "subscription_active",
          type: "bool",
          system: false,
          required: false,
          presentable: false,
          unique: false,
          options: {}
        }
      ],
      listRule: "id = @request.auth.user.business_id",
      viewRule: "id = @request.auth.user.business_id",
      createRule: "",
      updateRule: "id = @request.auth.user.business_id",
      deleteRule: "@request.auth.user.role = \"admin\" && id = @request.auth.user.business_id",
      options: {},
      indexes: []
    }),
    new Collection({
      id: "user",
      name: "user",
      type: "auth",
      system: false,
      schema: [
        {
          id: "role",
          name: "role",
          type: "text",
          system: false,
          required: true,
          presentable: false,
          unique: false,
          options: {
            min: null,
            max: null,
            pattern: ""
          }
        },
        {
          id: "business_id",
          name: "business_id",
          type: "text",
          system: false,
          required: true,
          presentable: false,
          unique: false,
          options: {
            min: null,
            max: null,
            pattern: ""
          }
        }
      ],
      listRule: "business_id = @request.auth.user.business_id",
      viewRule: "id = @request.auth.id || business_id = @request.auth.user.business_id",
      createRule: "",
      updateRule: "id = @request.auth.id || (@request.auth.user.role = \"admin\" && business_id = @request.auth.user.business_id)",
      deleteRule: "@request.auth.user.role = \"admin\" && business_id = @request.auth.user.business_id",
      options: {
        allowEmailAuth: true,
        allowOAuth2Auth: true,
        allowUsernameAuth: true,
        exceptEmailDomains: null,
        manageRule: null,
        minPasswordLength: 8,
        onlyEmailDomains: null,
        onlyVerified: false,
        requireEmail: false
      },
      indexes: []
    }),
    new Collection({
      id: "items",
      name: "items",
      type: "base",
      system: false,
      schema: [
        {
          id: "business_id",
          name: "business_id",
          type: "text",
          system: false,
          required: true,
          presentable: false,
          unique: false,
          options: {
            min: null,
            max: null,
            pattern: ""
          }
        },
        {
          id: "name",
          name: "name",
          type: "text",
          system: false,
          required: true,
          presentable: false,
          unique: false,
          options: {
            min: null,
            max: null,
            pattern: ""
          }
        },
        {
          id: "price",
          name: "price",
          type: "number",
          system: false,
          required: true,
          presentable: false,
          unique: false,
          options: {}
        },
        {
          id: "stock_qty",
          name: "stock_qty",
          type: "number",
          system: false,
          required: true,
          presentable: false,
          unique: false,
          options: {}
        }
      ],
      listRule: "business_id = @request.auth.user.business_id",
      viewRule: "business_id = @request.auth.user.business_id",
      createRule: "@request.auth.user.role = \"admin\" && business_id = @request.auth.user.business_id",
      updateRule: "@request.auth.user.role = \"admin\" && business_id = @request.auth.user.business_id",
      deleteRule: "@request.auth.user.role = \"admin\" && business_id = @request.auth.user.business_id",
      options: {},
      indexes: []
    }),
    new Collection({
      id: "sales",
      name: "sales",
      type: "base",
      system: false,
      schema: [
        {
          id: "business_id",
          name: "business_id",
          type: "text",
          system: false,
          required: true,
          presentable: false,
          unique: false,
          options: {
            min: null,
            max: null,
            pattern: ""
          }
        },
        {
          id: "user",
          name: "user",
          type: "text",
          system: false,
          required: true,
          presentable: false,
          unique: false,
          options: {
            min: null,
            max: null,
            pattern: ""
          }
        },
        {
          id: "user_email",
          name: "user_email",
          type: "text",
          system: false,
          required: true,
          presentable: false,
          unique: false,
          options: {
            min: null,
            max: null,
            pattern: ""
          }
        },
        {
          id: "items",
          name: "items",
          type: "json",
          system: false,
          required: true,
          presentable: false,
          unique: false,
          options: {}
        },
        {
          id: "total_amount",
          name: "total_amount",
          type: "number",
          system: false,
          required: true,
          presentable: false,
          unique: false,
          options: {}
        },
        {
          id: "payment_method",
          name: "payment_method",
          type: "text",
          system: false,
          required: true,
          presentable: false,
          unique: false,
          options: {
            min: null,
            max: null,
            pattern: ""
          }
        },
        {
          id: "receipt_no",
          name: "receipt_no",
          type: "text",
          system: false,
          required: true,
          presentable: false,
          unique: false,
          options: {
            min: null,
            max: null,
            pattern: ""
          }
        },
        {
          id: "payment_reference",
          name: "payment_reference",
          type: "text",
          system: false,
          required: false,
          presentable: false,
          unique: false,
          options: {
            min: null,
            max: null,
            pattern: ""
          }
        }
      ],
      listRule: "business_id = @request.auth.user.business_id",
      viewRule: "business_id = @request.auth.user.business_id",
      createRule: "@request.auth.id != \"\" && @request.data.business_id = @request.auth.user.business_id && @request.data.user = @request.auth.id",
      updateRule: "@request.auth.user.role = \"admin\" && business_id = @request.auth.user.business_id",
      deleteRule: "@request.auth.user.role = \"admin\" && business_id = @request.auth.user.business_id",
      options: {},
      indexes: []
    }),
    new Collection({
      id: "audit_logs",
      name: "audit_logs",
      type: "base",
      system: false,
      schema: [
        {
          id: "business_id",
          name: "business_id",
          type: "text",
          system: false,
          required: true,
          presentable: false,
          unique: false,
          options: {
            min: null,
            max: null,
            pattern: ""
          }
        },
        {
          id: "user_id",
          name: "user_id",
          type: "text",
          system: false,
          required: true,
          presentable: false,
          unique: false,
          options: {
            min: null,
            max: null,
            pattern: ""
          }
        },
        {
          id: "user_email",
          name: "user_email",
          type: "text",
          system: false,
          required: true,
          presentable: false,
          unique: false,
          options: {
            min: null,
            max: null,
            pattern: ""
          }
        },
        {
          id: "action",
          name: "action",
          type: "text",
          system: false,
          required: true,
          presentable: false,
          unique: false,
          options: {
            min: null,
            max: null,
            pattern: ""
          }
        },
        {
          id: "details",
          name: "details",
          type: "json",
          system: false,
          required: false,
          presentable: false,
          unique: false,
          options: {}
        }
      ],
      listRule: "(@request.auth.id != \"\" && user_id = @request.auth.id && business_id = @request.auth.user.business_id) || (@request.auth.user.role = \"admin\" && business_id = @request.auth.user.business_id)",
      viewRule: "(@request.auth.id != \"\" && user_id = @request.auth.id && business_id = @request.auth.user.business_id) || (@request.auth.user.role = \"admin\" && business_id = @request.auth.user.business_id)",
      createRule: "@request.auth.id != \"\" && @request.data.user_id = @request.auth.id && @request.data.business_id = @request.auth.user.business_id",
      updateRule: "@request.auth.user.role = \"admin\" && business_id = @request.auth.user.business_id",
      deleteRule: "@request.auth.user.role = \"admin\" && business_id = @request.auth.user.business_id",
      options: {},
      indexes: []
    }),
    new Collection({
      id: "attendance",
      name: "attendance",
      type: "base",
      system: false,
      schema: [
        {
          id: "user_id",
          name: "user_id",
          type: "text",
          system: false,
          required: true,
          presentable: false,
          unique: false,
          options: {
            min: null,
            max: null,
            pattern: ""
          }
        },
        {
          id: "business_id",
          name: "business_id",
          type: "text",
          system: false,
          required: true,
          presentable: false,
          unique: false,
          options: {
            min: null,
            max: null,
            pattern: ""
          }
        },
        {
          id: "checkin_time",
          name: "checkin_time",
          type: "text",
          system: false,
          required: true,
          presentable: false,
          unique: false,
          options: {
            min: null,
            max: null,
            pattern: ""
          }
        },
        {
          id: "checkout_time",
          name: "checkout_time",
          type: "text",
          system: false,
          required: false,
          presentable: false,
          unique: false,
          options: {
            min: null,
            max: null,
            pattern: ""
          }
        }
      ],
      listRule: "(@request.auth.id != \"\" && user_id = @request.auth.id && business_id = @request.auth.user.business_id) || (@request.auth.user.role = \"admin\" && business_id = @request.auth.user.business_id)",
      viewRule: "(@request.auth.id != \"\" && user_id = @request.auth.id && business_id = @request.auth.user.business_id) || (@request.auth.user.role = \"admin\" && business_id = @request.auth.user.business_id)",
      createRule: "@request.auth.id != \"\" && @request.data.user_id = @request.auth.id && @request.data.business_id = @request.auth.user.business_id",
      updateRule: "(@request.auth.id != \"\" && user_id = @request.auth.id && business_id = @request.auth.user.business_id) || (@request.auth.user.role = \"admin\" && business_id = @request.auth.user.business_id)",
      deleteRule: "@request.auth.user.role = \"admin\" && business_id = @request.auth.user.business_id",
      options: {},
      indexes: []
    })
  ];

  return Dao(db).importCollections(collections, false, null);
}, (db) => {
  return null;
})
