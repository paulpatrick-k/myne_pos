# PocketBase API Rules Configuration - Quick Checklist

## How to Apply These Rules

1. Open PocketBase Admin: http://127.0.0.1:8090/_/
2. For EACH collection below:
   - Click **Collections** in left sidebar
   - Click the collection name
   - Click **API Rules** tab
   - For each action (List, Create, Update, Delete):
     - Click the rule row
     - CLEAR the existing rule (if any)
     - PASTE the new rule from below
     - Click **Save**

---

## ✅ `attendance` Collection

### List Rule
```
(@request.auth.id != "" && user_id = @request.auth.id && business_id = @request.auth.user.business_id) || (@request.auth.user.role = "admin" && business_id = @request.auth.user.business_id)
```

### Create Rule
```
@request.auth.id != "" && @request.data.user_id = @request.auth.id && @request.data.business_id = @request.auth.user.business_id
```

### Update Rule
```
@request.auth.id != "" && user_id = @request.auth.id && business_id = @request.auth.user.business_id
```

### Delete Rule
```
@request.auth.user.role = "admin" && business_id = @request.auth.user.business_id
```

---

## ✅ `sales` Collection

### List Rule
```
business_id = @request.auth.user.business_id
```

### Create Rule
```
@request.auth.id != "" && @request.data.business_id = @request.auth.user.business_id && @request.data.user = @request.auth.id
```

### Update Rule
```
@request.auth.user.role = "admin" && business_id = @request.auth.user.business_id
```

### Delete Rule
```
@request.auth.user.role = "admin" && business_id = @request.auth.user.business_id
```

---

## ✅ `audit_logs` Collection

### List Rule
```
(@request.auth.id != "" && user_id = @request.auth.id && business_id = @request.auth.user.business_id) || (@request.auth.user.role = "admin" && business_id = @request.auth.user.business_id)
```

### Create Rule
```
@request.auth.id != "" && @request.data.user_id = @request.auth.id && @request.data.business_id = @request.auth.user.business_id
```

### Update Rule
```
@request.auth.user.role = "admin" && business_id = @request.auth.user.business_id
```

### Delete Rule
```
@request.auth.user.role = "admin" && business_id = @request.auth.user.business_id
```

---

## ✅ `items` Collection (Verify/Update)

### List Rule
```
business_id = @request.auth.user.business_id
```

### Create Rule
```
@request.auth.user.role = "admin" && business_id = @request.auth.user.business_id
```

### Update Rule
```
@request.auth.user.role = "admin" && business_id = @request.auth.user.business_id
```

### Delete Rule
```
@request.auth.user.role = "admin" && business_id = @request.auth.user.business_id
```

---

## Configuration Steps

### Step 1: Log into PocketBase Admin
- URL: http://127.0.0.1:8090/_/
- Use your admin credentials

### Step 2: Navigate to Collections
- Left sidebar → **Collections**

### Step 3: For Each Collection (attendance, sales, audit_logs, items)

1. Click the collection name
2. Click **API Rules** tab (should show 5 rows: List, Create, Read, Update, Delete)
3. **For List row:**
   - Click to expand
   - Clear existing filter
   - Paste List rule from above
   - Save
4. **For Create row:**
   - Click to expand
   - Clear existing filter
   - Paste Create rule from above
   - Save
5. **For Update row:**
   - Click to expand
   - Clear existing filter
   - Paste Update rule from above
   - Save
6. **For Delete row:**
   - Click to expand
   - Clear existing filter
   - Paste Delete rule from above
   - Save

### Step 4: Verify Configuration
- After saving each collection, the rules should show in the API Rules tab
- No errors should appear

---

## Testing After Configuration

### Test Attendance Create (Staff):
1. Open PocketBase API Explorer
2. Collections → attendance → POST (Create)
3. Use staff token (login as staff in Flutter app)
4. Body:
```json
{
  "user_id": "staff_user_id",
  "business_id": "business_id",
  "checkin_time": "2024-01-15T09:00:00.000Z"
}
```
5. Expected: 200 OK with record

### Test Attendance List (Staff):
1. GET /collections/attendance/records?filter=...
2. With staff token
3. Should return only own records

### Test Attendance List (Admin):
1. Same GET with admin token
2. Should return all records for business

### If 400 Errors Occur:
1. Check PocketBase logs: http://127.0.0.1:8090/_/logs
2. Verify API rule syntax (no typos, proper spacing)
3. Verify `user.business_id` field exists in users collection
4. Re-save rules and try again

---

## Common Issues

| Issue | Solution |
|-------|----------|
| 400 error on staff create | Check Create rule syntax, verify `@request.auth.id` is available |
| Staff can't see own records | Check List rule includes `user_id = @request.auth.id` |
| Admin can't see all records | Check List rule includes admin condition with `\|\|` (OR) |
| Syntax error in rule | Copy-paste from above, ensure no extra spaces |

---

## Rule Reference

**Key Variables:**
- `@request.auth.id` = authenticated user's ID
- `@request.auth.user.role` = user's role ("admin" or "staff")
- `@request.auth.user.business_id` = user's business ID
- `@request.data.*` = fields being created/updated
- `||` = OR operator
- `&&` = AND operator

**Common Patterns:**
- `@request.auth.id != ""` = user is authenticated
- `@request.auth.user.role = "admin"` = user is admin
- `user_id = @request.auth.id` = record belongs to user
- `business_id = @request.auth.user.business_id` = record in user's business

---

## Quick Copy-Paste Template

For each collection, use this template:

```
attendance:
- List: user_id = @request.auth.id && business_id = @request.auth.user.business_id || @request.auth.user.role = "admin" && business_id = @request.auth.user.business_id
- Create: @request.auth.id != "" && @request.data.user_id = @request.auth.id && @request.data.business_id = @request.auth.user.business_id
- Update: user_id = @request.auth.id && business_id = @request.auth.user.business_id || @request.auth.user.role = "admin" && business_id = @request.auth.user.business_id
- Delete: @request.auth.user.role = "admin" && business_id = @request.auth.user.business_id
```

---

**Estimated Time:** 5-10 minutes to configure all collections

**After Configuration:** App should work without 400 errors for staff operations
