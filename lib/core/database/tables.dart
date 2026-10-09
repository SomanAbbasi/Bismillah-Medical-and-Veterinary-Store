import 'package:drift/drift.dart';

class Medicines extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get genericName => text().withDefault(const Constant(''))();
  TextColumn get brand => text().withDefault(const Constant(''))();
  TextColumn get category => text().withDefault(const Constant('General'))();
  DateTimeColumn get expiryDate => dateTime()();
  TextColumn get notes => text().nullable()();
  IntColumn get reminderMonths => integer().nullable()(); // Custom reminder months (1, 2, 3, 6)
  IntColumn get reminderLeadDays => integer().nullable()(); // Custom reminder lead days (e.g. 15, 30, 60, 90)
  IntColumn get reminderIntervalMinutes => integer().nullable()(); // Custom repeat interval in minutes (null = default daily)
  IntColumn get preferredHour => integer().withDefault(const Constant(9))(); // Preferred notification hour (0-23)
  IntColumn get preferredMinute => integer().withDefault(const Constant(0))(); // Preferred notification minute (0-59)
  IntColumn get notificationId => integer().nullable()(); // Stable notification identifier
  DateTimeColumn get lastScheduledAt => dateTime().nullable()(); // Last time scheduled
  DateTimeColumn get nextScheduledAt => dateTime().nullable()(); // Next scheduled reminder time
  BoolColumn get isReminderDisabled => boolean().withDefault(const Constant(false))();
  BoolColumn get isDraft => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get phone => text()();
  TextColumn get alternativePhone => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get photoPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

class CustomerTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get customerId => integer().references(Customers, #id)();
  DateTimeColumn get date => dateTime()();
  IntColumn get amountPaisa => integer()();
  TextColumn get type => text()(); // 'credit', 'payment'
  TextColumn get reference => text().nullable()();
  TextColumn get paymentMethod => text().nullable()(); // Cash, Bank Transfer, EasyPaisa / JazzCash, Other
  TextColumn get otherPaymentMethod => text().nullable()(); // Custom method name when paymentMethod == 'Other'
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

class Suppliers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get phone => text()();
  TextColumn get company => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

class SupplierTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get supplierId => integer().references(Suppliers, #id)();
  DateTimeColumn get date => dateTime()();
  IntColumn get amountPaisa => integer()();
  TextColumn get type => text()(); // 'payable', 'payment'
  TextColumn get reference => text().nullable()(); // e.g. Bill / Invoice #
  TextColumn get paymentMethod => text().nullable()(); // Cash, Bank Transfer, EasyPaisa / JazzCash, Other
  TextColumn get otherPaymentMethod => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

class Sales extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  TextColumn get title => text().withDefault(const Constant('Store Sale'))();
  IntColumn get customerId => integer().nullable().references(Customers, #id)();
  IntColumn get totalAmountPaisa => integer()();
  IntColumn get discountPaisa => integer().withDefault(const Constant(0))();
  IntColumn get finalAmountPaisa => integer()();
  TextColumn get paymentType => text().withDefault(const Constant('cash'))(); // 'cash', 'credit'
  IntColumn get cashPaidPaisa => integer().withDefault(const Constant(0))();
  IntColumn get creditAmountPaisa => integer().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  IntColumn get amountPaisa => integer()();
  TextColumn get title => text().withDefault(const Constant('Store Expense'))();
  TextColumn get category => text().nullable()(); // Optional category
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

class Attachments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text()(); // 'expense', 'customer', 'supplier', 'sale', 'medicine', 'general'
  IntColumn get entityId => integer()();
  TextColumn get filePath => text()();
  TextColumn get fileName => text()();
  TextColumn get mimeType => text().withDefault(const Constant('image/jpeg'))();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

class InAppNotifications extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  TextColumn get category => text()(); // 'expiry', 'credit_overdue', 'supplier_due', 'backup'
  TextColumn get relatedEntityType => text().nullable()();
  IntColumn get relatedEntityId => integer().nullable()();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  BoolColumn get isResolved => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
