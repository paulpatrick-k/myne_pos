# PocketBase API Rules for Phase 4 (Staff, Attendance, Audit, Sales)

## Collections and Their API Rules

### 1. `attendance` Collection
**Purpose:** Staff clock-in/out logs with timestamps.

**Fields:**
- `id` (auto)
- `user_id` (text, required) → links to `users`
- `business_id` (text, required) → links to `businesses`
- `checkin_time` (datetime, required)
- `checkout_time` (datetime, optional) → null while staff is clocked in

**API Rules:**

| Action | Rule | Description |
|--------|------|-------------|
| **List (Staff)** | `user_id = @request.auth.id && business_id = @request.auth.user.business_id` | Staff can only see their own attendance records for their business |
| **List (Admin)** | `business_id = @request.auth.user.business_id` | Admin can see all staff records for their business |
| **Create (Staff)** | `@request.auth.id != "" && @request.data.user_id = @request.auth.id && @request.data.business_id = @request.auth.user.business_id` | Staff can create their own records |
| **Create (Admin)** | `@request.auth.user.role = "admin"` | Admin can create records |
| **Update (Staff)** | `user_id = @request.auth.id && business_id = @request.auth.user.business_id` | Staff can only update their own open records (clock out) |
| **Update (Admin)** | `business_id = @request.auth.user.business_id` | Admin can update any business record |
| **Delete (Admin)** | `business_id = @request.auth.user.business_id` | Admin only |

---

### 2. `sales` Collection
**Purpose:** Sales transactions with items and payment tracking.

**Fields:**
- `id` (auto)
- `business_id` (text, required)
- `user_id` (text, required) → staff or admin who created
- `user_email` (text)
- `items` (json) → [{item_id, name, quantity, price}, ...]
- `total_amount` (number)
- `payment_method` (text)
- `payment_reference` (text)
- `receipt_no` (text, unique per business)
- `created` (datetime, auto)

**API Rules:**

| Action | Rule | Description |
|--------|------|-------------|
| **List** | `business_id = @request.auth.user.business_id` | Only users from this business |
| **Create (Staff/Admin)** | `@request.auth.id != "" && @request.data.business_id = @request.auth.user.business_id && @request.data.user_id = @request.auth.id` | Must be authenticated, same business, own user_id |
| **Update (Admin)** | `business_id = @request.auth.user.business_id` | Admin only |
| **Delete (Admin)** | `business_id = @request.auth.user.business_id && @request.auth.user.role = "admin"` | Admin only |

---

### 3. `audit_logs` Collection
**Purpose:** Track staff actions on cart (quantity changes, removals).

**Fields:**
- `id` (auto)
- `business_id` (text, required)
- `user_id` (text, required)
- `user_email` (text)
- `action` (text) → e.g., "decrease_qty", "remove_item"
- `details` (json) → {item_id, item_name, old_qty, new_qty, ...}
- `created` (datetime, auto)

**API Rules:**

| Action | Rule | Description |
|--------|------|-------------|
| **List (Admin)** | `business_id = @request.auth.user.business_id` | Admin sees all business audit logs |
| **List (Staff)** | `user_id = @request.auth.id && business_id = @request.auth.user.business_id` | Staff only sees their own |
| **Create (Staff/Admin)** | `@request.auth.id != "" && @request.data.user_id = @request.auth.id && @request.data.business_id = @request.auth.user.business_id` | Any authenticated user in business |
| **Delete (Admin)** | `business_id = @request.auth.user.business_id && @request.auth.user.role = "admin"` | Admin only |

---

### 4. `users` Collection (already exists, verify)
**Fields required for Phase 4:**
- `id` (auto)
- `business_id` (text, required) → links to `businesses`
- `role` (text: "admin" or "staff", required)
- `email` (text, unique per business)
- `password` (password field)

---

### 5. `businesses` Collection (already exists, verify)
**Fields required:**
- `id` (auto)
- `business_code` (text, unique)
- `subscription_active` (bool, default true)
- `trial_end` (date **stored as ISO string**, e.g., "2026-12-31T23:59:59.000Z")

---

## Setup Steps in PocketBase Admin Panel

1. **Navigate to Settings → Collections**
2. **For each collection (attendance, audit_logs, sales):**
   - Click the collection
   - Go to **API Rules** tab
   - For each action (list, create, update, delete):
     - Click the rule
     - Paste the corresponding rule from table above
     - Save
3. **Verify `users.business_id` exists** - if not, add a Text field
4. **Verify `sales.receipt_no` is unique** within the collection
5. **Test:** Use the API Explorer in PocketBase to test filters with a staff token

---

## Troubleshooting

**400 Error on `getCurrentCheckin`:**
- Check: Is the `business_id` field present and populated in attendance records?
- Check: Are the List rules allowing the filter `user_id = ... && business_id = ...`?
- Test API: In PocketBase API Explorer, GET `/collections/attendance/records?filter=...` with staff token

**Staff cannot create sales:**
- Check: Does the staff have `user_id` in the sales.create rule?
- Verify: `user.business_id` matches `sales.business_id`

**Admin sees no audit logs:**
- Check: `audit_logs.list` rule has `business_id = @request.auth.user.business_id`
