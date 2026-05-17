# Phase 4 Implementation Guide: Staff Management & Multi-Role Access

## Objective
Enable staff to clock in/out, add items to cart, checkout, and have admin see audit logs — while maintaining backward compatibility with existing admin POS features.

---

## Part 1: PocketBase Configuration

### Step 1: Verify Collection Structure

1. Open PocketBase Admin Dashboard: http://127.0.0.1:8090/_/
2. Go to **Collections**
3. Verify these collections exist:
   - `users` (with fields: id, email, password, role, business_id, created, updated)
   - `businesses` (with fields: id, business_code, subscription_active, trial_end, category, created, updated)
   - `items`
   - `sales`
   - `attendance`
   - `audit_logs`

### Step 2: Update Field Types

Go to **Collections** → select each collection and verify:

**users collection:**
- `role` should be **Text** field (values: "admin", "staff")
- `business_id` should be **Text** field (linking to businesses)

**businesses collection:**
- `trial_end` should be **Date** field (displayed as ISO string: "2026-12-31T00:00:00.000Z")
- `subscription_active` should be **Boolean** field (default: true)

**attendance collection:**
- `user_id` → Text (links to users)
- `business_id` → Text (links to businesses)
- `checkin_time` → DateTime field
- `checkout_time` → DateTime field (allow empty)

**audit_logs collection:**
- `user_id` → Text
- `business_id` → Text
- `action` → Text
- `details` → JSON field

**sales collection:**
- `user_id` → Text
- `business_id` → Text
- `user_email` → Text
- `items` → JSON
- `total_amount` → Number
- `payment_method` → Text
- `payment_reference` → Text
- `receipt_no` → Text (mark as **unique** within collection)

---

## Part 3: Configure API Rules

**CRITICAL:** Without these rules, all staff operations return 400 errors.

### For `attendance` Collection:

1. Click **Collections** → **attendance** → **API Rules** tab
2. For each rule below, click the action and paste the filter:

| Action | Filter |
|--------|--------|
| **List** | `user_id = @request.auth.id && business_id = @request.auth.user.business_id \|\| @request.auth.user.role = "admin" && business_id = @request.auth.user.business_id` |
| **Create** | `@request.auth.id != "" && @request.data.user_id = @request.auth.id && @request.data.business_id = @request.auth.user.business_id` |
| **Update** | `user_id = @request.auth.id && business_id = @request.auth.user.business_id \|\| @request.auth.user.role = "admin" && business_id = @request.auth.user.business_id` |
| **Delete** | `@request.auth.user.role = "admin" && business_id = @request.auth.user.business_id` |

### For `sales` Collection:

1. Click **Collections** → **sales** → **API Rules** tab

| Action | Filter |
|--------|--------|
| **List** | `business_id = @request.auth.user.business_id` |
| **Create** | `@request.auth.id != "" && @request.data.business_id = @request.auth.user.business_id && @request.data.user_id = @request.auth.id` |
| **Update** | `@request.auth.user.role = "admin" && business_id = @request.auth.user.business_id` |
| **Delete** | `@request.auth.user.role = "admin" && business_id = @request.auth.user.business_id` |

### For `audit_logs` Collection:

1. Click **Collections** → **audit_logs** → **API Rules** tab

| Action | Filter |
|--------|--------|
| **List** | `user_id = @request.auth.id && business_id = @request.auth.user.business_id \|\| @request.auth.user.role = "admin" && business_id = @request.auth.user.business_id` |
| **Create** | `@request.auth.id != "" && @request.data.user_id = @request.auth.id && @request.data.business_id = @request.auth.user.business_id` |
| **Delete** | `@request.auth.user.role = "admin" && business_id = @request.auth.user.business_id` |

### For `items` Collection (verify admin can list/create):

| Action | Filter |
|--------|--------|
| **List** | `business_id = @request.auth.user.business_id` |
| **Create** | `@request.auth.user.role = "admin" && business_id = @request.auth.user.business_id` |
| **Update** | `@request.auth.user.role = "admin" && business_id = @request.auth.user.business_id` |
| **Delete** | `@request.auth.user.role = "admin" && business_id = @request.auth.user.business_id` |

---

## Part 4: Dart Code Updates (Already Applied)

✅ The following fixes have been applied to the codebase:

1. **lib/shared/providers/auth_provider.dart:**
   - `isLicenseExpired()` now checks both `_subscriptionActive` flag AND trial_end date
   - `refreshLicenseFromServer()` safely parses trial_end as DateTime

2. **lib/core/services/pocketbase_service.dart:**
   - `getCurrentCheckin()` now includes `checkout_time = null` filter in API query
   - `getBusinessLicense()` returns DateTime for trial_end and bool for subscription_active

3. **lib/features/cart/checkout_screen.dart:**
   - Added license expiry check before processing checkout
   - Added staff clock-in verification before allowing transactions

4. **lib/features/staff/staff_home_screen.dart:**
   - Created all-in-one staff panel with clock-in/out, cart, items list

5. **lib/features/audit/audit_log_screen.dart:**
   - Displays staff cart actions with timestamps

---

## Part 5: Testing Checklist

### Pre-Testing Setup

```bash
# Navigate to project directory
cd c:\Users\user\Desktop\myne_pos

# Clean and get dependencies
flutter clean
flutter pub get

# Verify no compilation errors
flutter analyze lib/
```

### Test Flow (Staff Perspective)

1. **Login as Staff:**
   - Launch app: `flutter run -d windows`
   - Use staff credentials (non-admin user)
   - Expected: Should redirect to StaffHomeScreen (not admin dashboard)

2. **Clock In:**
   - Click the **Clock In** button (top-left of StaffHomeScreen)
   - Expected: Button changes to "Clock Out", status bar turns **green** with "Transactions Allowed"

3. **Add Items to Cart:**
   - Search for items in the search bar
   - Click "Add to Cart" on items
   - Expected: Items appear in cart (only works when clocked in)

4. **Modify Cart:**
   - Decrease quantity → should create audit log entry
   - Remove item → should create audit log entry

5. **Checkout:**
   - Click "Checkout" button
   - Select payment method
   - Submit
   - Expected: Sale created, stock deducted, offline queue NOT used (online sync)

6. **Clock Out:**
   - Click "Clock Out" button
   - Expected: Status bar turns **red** with "Transactions Blocked"
   - Cannot add items after clocking out

### Test Flow (Admin Perspective)

1. **Login as Admin:**
   - Use admin credentials
   - Expected: See admin dashboard with "Staff Management", "Audit Logs", "Attendance Logs", "Manage Items"

2. **View Attendance Logs:**
   - Click "Attendance Logs"
   - Expected: See all staff clock-in/out times with timestamps

3. **View Audit Logs:**
   - Click "Audit Logs"
   - Expected: See all staff cart actions (quantity changes, removals) with timestamps

4. **Verify Stock Deduction:**
   - Click "Manage Items"
   - Expected: See stock quantities decreased after staff checkout

---

## Part 6: Troubleshooting

### Issue: `flutter analyze` shows errors

**Solution:**
```bash
flutter clean
flutter pub get
flutter analyze
```

If errors persist, check:
- Dart SDK version: `dart --version` (should be >= 3.0)
- Flutter version: `flutter --version`

### Issue: App crashes on launch

**Check logs:**
```bash
flutter run -d windows -v  # verbose output
```

Look for:
- Hive box initialization errors → check Hive setup in main.dart
- PocketBase connection errors → verify PocketBase is running on http://127.0.0.1:8090
- Provider initialization errors → check MultiProvider setup in main.dart

### Issue: Staff sees 400 error when clocking in

**Diagnosis:**
1. Check PocketBase logs: http://127.0.0.1:8090/_/logs
2. Verify `attendance` collection API rules are set (see Part 3)
3. Test API manually:
   - Open PocketBase Admin → **API Explorer**
   - Select **Collections** → **attendance**
   - POST (create) with body:
   ```json
   {
     "user_id": "staff_user_id",
     "business_id": "business_id",
     "checkin_time": "2024-01-15T09:00:00.000Z"
   }
   ```
   - If 400 error, check API rule syntax

### Issue: Admin cannot see attendance logs

**Check:**
1. Verify attendance collection **List** API rule includes: `|| @request.auth.user.role = "admin"`
2. Test: `getAttendanceLogs(businessId)` should filter with `business_id = "businessId"`

### Issue: Sales not being created for staff

**Check:**
1. Verify `sales` collection **Create** API rule: `@request.data.user_id = @request.auth.id`
2. Verify staff user has correct `role = "staff"` in database
3. Check PocketBase logs for detailed error

### Issue: Stock not deducting after checkout

**Check:**
1. Verify `createSale()` in pocketbase_service.dart calls item updates
2. Check that `items` collection has `stock_qty` field
3. Look in sales record to confirm items array has correct structure

---

## Part 7: Deployment Validation

### Pre-Production Checklist

- [ ] All staff operations work without 400 errors
- [ ] Admin can see attendance and audit logs
- [ ] Stock deduction works for both admin and staff
- [ ] License expiry prevents checkout when subscription inactive
- [ ] Offline sync still works (disconnect WiFi and create sale → reconnect)
- [ ] Previous Phase 1-3 features intact:
  - [ ] Admin can manage items
  - [ ] Admin can view sales history
  - [ ] Admin can manage categories
  - [ ] Cart works for admin
  - [ ] Checkout with multiple payment methods
  - [ ] Offline sales queue and sync
  - [ ] Receipt printing

### Commands to Validate

```bash
# Build for Windows (if deploying)
flutter build windows --release

# Check build size and startup time
# Run multiple times to verify no crashes

# Clean rebuild
flutter clean
flutter pub get
flutter run -d windows
```

---

## Part 8: Code Review Checklist

✅ **DateTime Handling:**
- [ ] All `.get<DateTime>()` calls removed (not available in SDK v0.18.1)
- [ ] All date fields parsed with `DateTime.tryParse()` from ISO strings
- [ ] No hardcoded dates

✅ **Permission Checks:**
- [ ] Staff cannot access admin screens (routes protected)
- [ ] Admin can access all screens
- [ ] Checkout requires staff to be clocked in
- [ ] License expiry blocks checkout

✅ **Audit Logging:**
- [ ] Cart quantity changes logged
- [ ] Cart item removals logged
- [ ] Timestamps auto-added by PocketBase (created field)

✅ **Backward Compatibility:**
- [ ] Admin POS features unchanged
- [ ] Existing offline sync still works
- [ ] Receipt generation unchanged

---

## Next Steps

1. **Configure PocketBase API Rules** (Part 3) - MUST DO FIRST
2. **Run Flutter commands** (Part 6)
3. **Test all flows** (Part 5)
4. **Check PocketBase logs** if errors occur
5. **Iterate on fixes** as needed

**Estimated Time:** 30-45 minutes for full validation including testing.
