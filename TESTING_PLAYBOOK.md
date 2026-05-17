# Phase 4 Testing & Validation Playbook

## Pre-Testing Checklist

Before running the Flutter app:

- [ ] PocketBase is running on http://127.0.0.1:8090
- [ ] All API rules configured in PocketBase (see POCKETBASE_QUICK_SETUP.md)
- [ ] Staff user created in PocketBase (role="staff")
- [ ] Admin user created or existing (role="admin")
- [ ] Both users linked to same business
- [ ] At least one item created for the business
- [ ] Windows development environment ready

---

## Testing Sequence

### Stage 1: Verify Build (5 minutes)

```bash
cd c:\Users\user\Desktop\myne_pos

# Clean build artifacts
flutter clean

# Get all dependencies
flutter pub get

# Verify no compilation errors
flutter analyze lib/
```

**Expected Output:**
```
No issues found! (ran in X.Xs)
```

If errors appear, fix them before proceeding.

---

### Stage 2: Launch App (2 minutes)

```bash
flutter run -d windows
```

**Expected Behavior:**
- App launches
- Shows login screen
- No crashes or stack traces

---

### Stage 3: Staff Workflow Test (10 minutes)

#### 3.1 Login as Staff

1. **On login screen:**
   - Email: `staff@business.com` (or your staff user)
   - Password: [staff password]
   - Click **Login**

2. **Expected:** 
   - ✅ App redirects to `StaffHomeScreen` (NOT admin dashboard)
   - ✅ AppBar shows "Clock In" button
   - ✅ Status bar shows **RED** text: "Transactions Blocked"

#### 3.2 Clock In

1. **Click "Clock In" button** (top-left of AppBar)
   
2. **Expected:**
   - ✅ Button text changes to "Clock Out"
   - ✅ Status bar turns **GREEN**: "Transactions Allowed"
   - ✅ No error dialog

   **If 400 error appears:**
   - Check PocketBase logs: http://127.0.0.1:8090/_/logs
   - Verify `attendance` collection API rules (List, Create)
   - Re-read POCKETBASE_QUICK_SETUP.md and update rules

#### 3.3 Add Items to Cart

1. **Search for an item:**
   - Type item name in search bar (e.g., "apple", "soda")
   - Expected: Items list filters in real-time

2. **Add item to cart:**
   - Click "Add to Cart" button on an item
   - Expected:
     - ✅ Item appears in cart
     - ✅ Cart icon badge shows count (e.g., "🛒 1")
     - ✅ No error

   **If error appears when clocked out:**
   - ✅ This is correct behavior (transactions blocked)
   - Clock in first, then try again

#### 3.4 Modify Cart (Verify Audit Logging)

1. **Increase quantity:**
   - Find item in cart
   - Click "+" button
   - Expected:
     - ✅ Quantity increases
     - ✅ Total amount updates

2. **Decrease quantity:**
   - Click "-" button
   - Expected:
     - ✅ Quantity decreases
     - ✅ Audit log entry created (admin will see this)

3. **Remove item:**
   - Click "Remove" button or trash icon
   - Expected:
     - ✅ Item removed from cart
     - ✅ Badge count decreases
     - ✅ Audit log entry created

#### 3.5 Checkout

1. **Click "Checkout" button**

2. **Select payment method:**
   - Cash, Card, Mobile Money, or Cheque
   - Enter reference (if applicable)

3. **Expected:**
   - ✅ Sale created successfully
   - ✅ Stock quantities decreased (admin will verify)
   - ✅ Cart clears
   - ✅ Confirmation message

   **If 400 error on checkout:**
   - Verify `sales` collection Create rule
   - Check license is active (`subscription_active = true`)
   - Check you're still clocked in

#### 3.6 Clock Out

1. **Click "Clock Out" button** (in AppBar)

2. **Expected:**
   - ✅ Button changes to "Clock In"
   - ✅ Status bar turns **RED**: "Transactions Blocked"
   - ✅ "Add to Cart" buttons are disabled
   - ✅ Cannot click checkout

---

### Stage 4: Admin Workflow Test (8 minutes)

#### 4.1 Logout & Login as Admin

1. **Click logout** (usually in menu)
   
2. **Expected:**
   - ✅ App returns to login screen
   - ✅ All local data cleared (Hive)

3. **Login as admin:**
   - Email: `admin@business.com`
   - Password: [admin password]

4. **Expected:**
   - ✅ App shows admin dashboard
   - ✅ Navigation tiles: "Staff Management", "Audit Logs", "Attendance Logs", "Manage Items"

#### 4.2 View Attendance Logs

1. **Click "Attendance Logs" tile**

2. **Expected:**
   - ✅ Shows list of staff attendance records
   - ✅ Each record shows:
     - User email (staff who clocked in)
     - Clock-in time (ISO format or formatted)
     - Clock-out time (if clocked out)

3. **Verify staff entries:**
   - Should see the staff user's clock-in time
   - Should see clock-out time if staff clocked out

   **If no records appear:**
   - Verify `attendance` collection List rule for admin
   - Check PocketBase logs for permission errors

#### 4.3 View Audit Logs

1. **Click "Audit Logs" tile**

2. **Expected:**
   - ✅ Shows list of staff cart actions
   - ✅ Each log entry shows:
     - User email (staff who performed action)
     - Action (e.g., "decrease_quantity", "remove_item")
     - Details (JSON with item_id, quantities, etc.)
     - Timestamp

3. **Verify staff actions:**
   - Should see all quantity changes and removals from cart
   - Timestamps should match when staff was using cart

   **If no records appear:**
   - Verify `audit_logs` collection List rule for admin
   - Check that staff actually modified cart items

#### 4.4 Verify Stock Deduction

1. **Click "Manage Items" tile**

2. **Expected:**
   - ✅ Shows list of all items for business
   - ✅ Each item shows current `stock_qty`

3. **Compare to pre-sale stock:**
   - If staff sold 5 units of item "X", stock should be 5 less
   - Example:
     - Before: stock_qty = 100
     - After staff sale of 5 units: stock_qty = 95

   **If stock not changed:**
   - Check `createSale()` method updates item stock
   - Verify items in sales record have correct structure
   - Check PocketBase logs for SQL errors

---

### Stage 5: Offline Sync Test (5 minutes) [Optional]

1. **Disconnect WiFi/Network**

2. **Login as staff and perform actions:**
   - Clock in
   - Add items to cart
   - Checkout

3. **Expected:**
   - ✅ Transactions queue locally (Hive)
   - ✅ No network errors
   - ✅ Cart clears after checkout

4. **Reconnect Network**

5. **Expected:**
   - ✅ Queued sales sync to PocketBase
   - ✅ Admin sees sales records
   - ✅ Stock reflects changes

---

### Stage 6: License Expiry Kill-Switch Test (3 minutes) [Optional]

1. **As admin, update business record:**
   - Go to PocketBase admin
   - Collections → businesses → [business record]
   - Set `subscription_active = false`
   - Save

2. **Restart Flutter app or refresh auth**

3. **Try to checkout:**
   - Expected:
     - ✅ Dialog appears: "Subscription expired"
     - ✅ Checkout blocked
     - ✅ Cannot proceed

4. **Restore subscription:**
   - PocketBase: Set `subscription_active = true`
   - Refresh auth
   - Checkout should work again

---

## Expected Results Summary

| Scenario | Expected |
|----------|----------|
| Staff login | Redirects to StaffHomeScreen |
| Clock in | Button changes, status green, transactions allowed |
| Add item (clocked in) | Item in cart, audit log created |
| Add item (clocked out) | Button disabled, cannot add |
| Checkout (valid) | Sale created, stock decreased, cart cleared |
| Checkout (subscription expired) | Dialog error, checkout blocked |
| Clock out | Button changes, status red, transactions blocked |
| Admin views attendance | Sees all staff clock times |
| Admin views audit logs | Sees all staff cart actions |
| Admin views items | Sees updated stock quantities |

---

## Troubleshooting During Testing

### Issue: 400 Error on Any Staff Operation

**Steps:**
1. Check PocketBase logs: http://127.0.0.1:8090/_/logs
2. Look for the exact error message
3. Common causes:
   - API rule syntax error → Fix in POCKETBASE_QUICK_SETUP.md and re-apply
   - Missing field (e.g., `business_id` not set) → Verify data structure
   - User not authenticated → Check login worked

### Issue: Staff Sees Admin Dashboard

**Solution:**
1. Check user.role in PocketBase: Should be "staff", not "admin"
2. Verify staff user has correct business_id
3. Restart app (hot reload may not pick up role changes)

### Issue: Audit Logs Not Appearing

**Solution:**
1. Verify staff actually modified cart (decrease qty, remove item)
2. Check `logAuditAction()` calls in cart_screen.dart
3. Verify `audit_logs` collection Create rule allows staff
4. Check PocketBase logs for permission errors

### Issue: Stock Not Deducting

**Solution:**
1. Check items are in sales.items array with quantities
2. Verify `createSale()` calls item update endpoint
3. Check `items` collection Update rule allows business operations
4. Monitor PocketBase logs for SQL errors

### Issue: App Crashes on Flutter Run

**Solution:**
```bash
flutter clean
flutter pub get
flutter run -d windows -v  # verbose to see stack trace
```
Look for specific error in verbose output.

---

## Performance Notes

- **First launch:** May take 30-60 seconds (Dart compilation)
- **Subsequent launches:** 5-10 seconds (hot reload available)
- **Network calls:** Should be sub-second (local PocketBase)
- **List renders:** Should be smooth with <100 items

---

## Success Criteria

✅ **Phase 4 is Complete when:**

1. Staff can clock in/out without 400 errors
2. Staff can add items to cart only when clocked in
3. Staff can checkout and create sales
4. Stock quantities decrease after staff checkout
5. Admin sees attendance logs (all staff times)
6. Admin sees audit logs (all staff cart actions)
7. License expiry blocks checkout
8. All Phase 1-3 features still work (admin POS, items, offline)

---

## Final Checklist

Before considering Phase 4 "done":

- [ ] Staff workflow fully tested
- [ ] Admin workflow fully tested
- [ ] No 400 errors in any operation
- [ ] Attendance logs visible to admin
- [ ] Audit logs visible to admin
- [ ] Stock deduction verified
- [ ] License expiry kill-switch works
- [ ] Offline sync still works
- [ ] No Flutter errors or warnings (except lint)
- [ ] App runs smoothly on Windows

---

**Estimated Total Testing Time:** 30-45 minutes

**Expected Completion:** After successful execution of all tests above
