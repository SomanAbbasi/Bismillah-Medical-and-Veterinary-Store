# BismillahStore

**BismillahStore** is a production-grade, 100% offline-first Android application designed for independent pharmacy and medical store owners. It provides reliable medicine expiry date alerts with Android scheduled alarms, batch and lot tracking, customer credit ledgers (Udhar), supplier payables ledgers, daily sales and expense recording with photo attachments, and offline data backups.

---

## 🌟 Key Features

### 1. 100% Free & Offline-First Architecture
- **Local SQLite Database (Drift)**: All store records, medicines, batches, ledgers, sales, and expenses are persisted locally on device storage.
- **Zero Cloud or Subscription Requirements**: No internet, Firebase, paid backend, or logins required.

### 2. Reliable Android Medicine Expiry Notifications
- **Production Notification Subsystem**: Built with `flutter_local_notifications` and `timezone` using Android scheduled alarms, heads-up notifications, system audio, and boot receiver persistence (`RECEIVE_BOOT_COMPLETED`).
- **Fast 1-Minute Testing Mode**: Select "Every 1 Minute (Ultra Fast Test ⚡)" in Settings to verify notification alarms and sounds instantly.
- **Customizable Reminder Intervals**: Choose reminder frequencies (Every 1m, 15m, 30m, 1h, 2h, 6h, or Daily at 9:00 AM).
- **Customizable Reminder Lead Times**: Configure alert windows (30 days, 60 days, 90 days, 180 days, or custom date thresholds).
- **Batch / Lot Support**: Track multiple batches of the same medicine (e.g. Panadol with 2-month expiry batch and 1-year expiry batch).
- **Default Expiry Date**: Defaults to current date for fast and convenient medicine entry.
- **No Stock/Quantity Bloat**: Clean medicine tracking focusing on Medicine Name, Batch Number, Formula/Generic, Brand, Category, and Expiry Date with full editability.

### 3. Dual Ledger: Customer Credit & Supplier Payables
- **Customer Credit (Udhar)**: Track receivable balances from customers, record payment receipts, optional phone numbers, and share detailed statements.
- **Supplier Payables (Udhar)**: Track money owed to medicine distributors and suppliers, record invoices/bills, and log payment vouchers.
- **Full CRUD Support**: Add, edit, update, and soft-delete customer and supplier profiles and transactions.
- **Seamless Segmented Switching**: Switch between Customer Credit and Supplier Payables on the Ledger screen.

### 4. Daily Sales & Expenses
- **Daily Sales**: Title/Notes, Date, Amount (PKR), Cash or Credit, Customer Association, and Multiple Photo Proof Attachments.
- **Daily Expenses**: Title/Notes, Date, Amount (PKR), Optional Category, and Multiple Photo Proof Attachments.
- **Instant Auto-Refresh**: All dashboard summaries, totals, and ledgers automatically recompute the moment new sales or transactions are added.
- **30-Day Recycle Bin (Trash)**: Soft-deletion for all records with 1-tap Undo/Restore and automatic 30-day purge.

### 5. Document Attachments & Offline Backup
- Attach photos of receipts, paper invoices, doctor prescriptions, and payment slips directly from the camera or gallery.
- **Full ZIP Export/Import**: Backup database and attachments into a single portable ZIP file and restore anytime.

---

## 🛠️ Technology Stack
- **Framework**: Flutter / Dart
- **State Management**: Flutter Riverpod
- **Database**: SQLite / Drift ORM
- **Notifications**: Flutter Local Notifications with Timezone & Scheduled Alarms
- **Permissions**: Permission Handler (POST_NOTIFICATIONS, SCHEDULE_EXACT_ALARM, IGNORE_BATTERY_OPTIMIZATIONS)
- **Routing**: GoRouter
- **Security**: Local Biometrics & 4-Digit PIN App Lock

---

## 📦 Release APK
The compiled production release APK is located at:
- `BismillahStore.apk`

---

## 🚀 Installation via ADB
With phone connected via USB:
```bash
adb install -r BismillahStore.apk
```
Or copy `BismillahStore.apk` directly to phone storage and tap to install.
