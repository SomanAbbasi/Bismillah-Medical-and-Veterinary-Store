# PharmaLedger - Medical Store & Pharmacy Management

**PharmaLedger** is a production-grade, offline-first pharmacy and medical store management application engineered for independent pharmacy owners. It runs entirely on-device without mandatory cloud subscriptions, internet access, accounts, or external database backends.

---

## 🌟 Key Capabilities

### 1. 100% Offline-First Architecture
- **Local SQLite Source of Truth**: Powered by **Drift (Type-Safe SQLite ORM)**.
- **Zero Internet Requirement**: Every transaction, ledger entry, stock deduction, report generation, and backup works seamlessly with Wi-Fi and Mobile Data turned OFF.
- **Future-Ready Sync Hooks**: All core entities include UUID primary keys and ISO-8601 timestamps (`createdAt`, `updatedAt`), making cloud replication straightforward without rewriting business logic.

### 2. FEFO Batch Inventory Engine
- **Medicine vs. Batch Distinction**: Medicines (generic name, brand, category, dosage form, strength) contain multiple distinct batches with individual expiry dates, quantities, purchase rates, and retail prices.
- **FEFO (First-Expired, First-Out) Deduction**: During sales, stock is automatically depleted from the batch closest to expiry.
- **Automated Expiry Alerts**: Batches nearing expiration (< 1 month, < 3 months, < 6 months) trigger actionable warnings and recurring local notifications.
- **Physical Stock Adjustments**: Fast logging of expired stock dump, damaged items, and manual physical audits with complete audit trails.

### 3. Financial Integrity & Immutable Ledgers
- **Integer Minor Units (Paisa Arithmetic)**: All monetary values are strictly stored as integer paisas (1 PKR = 100 paisas) in SQLite to eliminate floating-point rounding errors.
- **Double-Entry Style Ledger History**:
  - **Customer Credit Accounts**: Opening balance + credit purchases + manual debits - payments - returns.
  - **Supplier Payables**: Opening payable + stock invoices + manual credits - payments - returns.
- **Real-Time Payment Recording**: Cash, bank transfer, and cheque support with instant balance reconciliation.

### 4. Sales & Expenses Management
- **Quick Cash Sale**: 3-second checkout for high-traffic counter sales without inventory lookup.
- **Detailed Prescription Sale**: Multi-item line items with dynamic batch allocation, instant profit margin calculation, and customer credit ledger association.
- **Expense Tracking**: Categorized overhead logs (Rent, Electricity, Salaries, Supplies, Maintenance, Delivery) with bill attachment support.

### 5. Document Attachments & Complete Backup
- **Supporting Images**: Capture or attach photos of paper invoices, prescription slips, handwritten registers, and deposit receipts.
- **ZIP-Based Full Export/Import**: Encapsulates SQLite database state and physical media attachments into a portable `.zip` archive alongside a SHA-256 metadata manifest.

### 6. Security & Privacy
- **Device Security**: Optional 4-digit PIN protection and native biometric authentication (Fingerprint / Face Unlock via `local_auth` and `FlutterFragmentActivity`).
- **Data Isolation**: All store records remain strictly inside the private application sandbox.

---

## 🏗️ Architecture & Technology Stack

| Layer | Technology |
|---|---|
| **Language / Framework** | Dart 3.10+ / Flutter 3.32+ |
| **State Management** | Riverpod (`flutter_riverpod`) |
| **Routing & Navigation** | `go_router` |
| **Database & Persistence** | Drift (SQLite ORM) with native sqlite3 binding |
| **Notifications** | `flutter_local_notifications` (Android Exact Alarms & Channels) |
| **Security & App Lock** | `local_auth` & `flutter_secure_storage` |
| **Media & File Storage** | `image_picker`, `file_picker`, `path_provider`, `archive` |
| **Export & Sharing** | `share_plus`, `intl` |

---

## 📁 Project Directory Structure

```
lib/
├── core/
│   ├── backup/             # Archive-based backup & restore service
│   ├── database/           # Drift schema (13 tables), connection, & provider
│   ├── files/              # Local image attachment storage & compression
│   ├── notifications/      # Local notification scheduler & channels
│   ├── routing/            # GoRouter configuration & route guards
│   ├── security/           # PIN & Biometric AppLock service
│   ├── theme/              # Color palette, spacing system, typography & ThemeData
│   ├── utils/              # Decimal-safe currency arithmetic, date formatters, expiry utils
│   └── widgets/            # Reusable UI cards, buttons, text fields, chips, & dialogs
├── features/
│   ├── customers/          # Customer directory, credit ledger, & payment collection
│   ├── dashboard/          # Daily KPI cards, action alerts, quick actions, global search
│   ├── expenses/           # Expense tracking, category breakdown, bill receipts
│   ├── expiry/             # Dedicated expiry inspection & action workbench
│   ├── inventory/          # Medicine catalog, batch tracking, FEFO adjustments
│   ├── main_navigation/   # Modern 5-tab persistent bottom navigation scaffold
│   ├── notifications/      # On-device notification alert center & filter
│   ├── onboarding/         # First-time welcome walkthrough & store initialization
│   ├── reports/            # Daily, weekly, monthly profit & ledger balance summaries
│   ├── sales/              # Quick sales, detailed multi-item counter checkout
│   ├── settings/           # Store profile, reminder thresholds, PIN lock, sample data
│   └── suppliers/          # Supplier directory, payable ledgers, purchase records
└── main.dart               # Entry point with orientation lock & security lock wrapper
```

---

## 🧪 Testing & Verification

The test suite covers financial math, expiry detection, and UI components:

```bash
# Run static analysis
flutter analyze

# Run unit and widget tests
flutter test
```

---

## 📦 Building and Installing

### 1. Release APK Compilation
```bash
flutter build apk --release
```
The output APK is generated at:
`build/app/outputs/flutter-apk/app-release.apk`

### 2. Direct Device Installation
```bash
flutter install -d <device_id>
# Or via ADB
adb -s <device_id> install -r build/app/outputs/flutter-apk/app-release.apk
```
