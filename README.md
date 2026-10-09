# PharmaLedger

**PharmaLedger** is a production-grade, 100% offline-first Android application designed for independent pharmacy and medical store owners. It provides medicine expiry date alerts, customer credit ledgers (Udhar), supplier payables ledgers, daily sales and expense recording with photo attachments, and offline data backups.

---

## 🌟 Key Features

### 1. 100% Free & Offline-First Architecture
- **Local SQLite Database (Drift)**: All business data, ledger entries, medicines, sales, and expenses are persisted locally on the device.
- **Zero Cloud or Subscription Requirements**: No internet, Firebase, paid backend, or logins required.

### 2. Reliable Android Medicine Expiry Notifications
- **Production Notification Subsystem**: Built with `flutter_local_notifications` and `timezone` using Android scheduled alarms and boot persistence.
- **Configurable Notification Intervals**: Choose reminder frequencies (e.g., every 15m, 30m, 1h, 2h, 6h, or Daily at 9:00 AM).
- **Customizable Reminder Lead Times**: Configure alert windows (30 days, 60 days, 90 days, 180 days, or custom date thresholds).
- **Diagnostic Dashboard**: Real-time permission status, active alarm count, next scheduled alert time, and 1-tap "Test Notification with Sound" button.
- **No Stock/Quantity Bloat**: Clean medicine tracking focusing on Medicine Name, Generic, Brand, Category, and Expiry Date with full editability.

### 3. Dual Ledger: Customer Credit & Supplier Payables
- **Customer Credit (Udhar)**: Track receivable balances from customers, record payment receipts, and share detailed statements.
- **Supplier Payables (Udhar)**: Track money owed to medicine distributors and suppliers, record invoices/bills, and log payment vouchers.
- **Seamless Segmented Switching**: Switch between Customer Credit and Supplier Payables on the Ledger screen.

### 4. Daily Sales & Expenses
- **Daily Sales**: Title/Notes, Date, Amount (PKR), Cash or Credit, Customer Association, and Multiple Photo Proof Attachments.
- **Daily Expenses**: Title/Notes, Date, Amount (PKR), Optional Category, and Multiple Photo Proof Attachments.
- **30-Day Recycle Bin (Trash)**: Soft-deletion for all records with 1-tap Undo/Restore and automatic 30-day purge.

### 5. Document Attachments & Offline Backup
- Attach photos of receipts, paper invoices, doctor prescriptions, and payment slips directly from the camera or gallery.
- **Full ZIP Export/Import**: Backup database and attachments into a single portable ZIP file and restore anytime.

---

## 🛠️ Technology Stack
- **Framework**: Flutter 3.44.6 / Dart 3.12.2
- **State Management**: Flutter Riverpod
- **Database**: SQLite / Drift ORM
- **Notifications**: Flutter Local Notifications with Timezone
- **Routing**: GoRouter
- **Security**: Local Biometrics & 4-Digit PIN App Lock

---

## 📦 Release APK
The compiled production release APK is located at:
- `PharmaLedger.apk`

---

## 🚀 Installation on Android Phone
1. Connect phone via USB or copy `PharmaLedger.apk` to phone storage.
2. Tap `PharmaLedger.apk` on the phone to install.
3. Grant notification permissions to receive scheduled medicine expiry audio alerts.
