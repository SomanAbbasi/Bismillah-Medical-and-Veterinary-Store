import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../database/database_provider.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/dashboard/presentation/global_search_screen.dart';
import '../../features/expenses/presentation/add_expense_screen.dart';
import '../../features/expiry/presentation/expiry_management_screen.dart';
import '../../features/inventory/presentation/add_batch_screen.dart';
import '../../features/inventory/presentation/add_edit_medicine_screen.dart';
import '../../features/inventory/presentation/inventory_adjustment_screen.dart';
import '../../features/inventory/presentation/inventory_list_screen.dart';
import '../../features/inventory/presentation/medicine_detail_screen.dart';
import '../../features/customers/presentation/add_credit_screen.dart';
import '../../features/customers/presentation/add_customer_screen.dart';
import '../../features/customers/presentation/customer_account_screen.dart';
import '../../features/customers/presentation/customers_screen.dart';
import '../../features/customers/presentation/record_payment_screen.dart';
import '../../features/main_navigation/presentation/main_scaffold.dart';
import '../../features/notifications/presentation/notification_center_screen.dart';
import '../../features/onboarding/presentation/welcome_screen.dart';
import '../../features/sales/presentation/new_sale_screen.dart';
import '../../features/sales/presentation/sale_detail_screen.dart';
import '../../features/sales/presentation/sales_and_expenses_screen.dart';
import '../../features/settings/presentation/backup_restore_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/suppliers/presentation/add_supplier_payable_screen.dart';
import '../../features/suppliers/presentation/add_supplier_screen.dart';
import '../../features/suppliers/presentation/record_supplier_payment_screen.dart';
import '../../features/suppliers/presentation/supplier_account_screen.dart';
import '../../features/suppliers/presentation/suppliers_screen.dart';
import '../../features/trash/presentation/trash_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorHomeKey = GlobalKey<NavigatorState>();
final _shellNavigatorInventoryKey = GlobalKey<NavigatorState>();
final _shellNavigatorLedgerKey = GlobalKey<NavigatorState>();
final _shellNavigatorReportsKey = GlobalKey<NavigatorState>();
final _shellNavigatorSettingsKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final db = ref.watch(databaseProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/dashboard',
    redirect: (context, state) async {
      final onboarding = await db.getSetting('onboarding_completed');
      final isOnboarding = state.matchedLocation == '/welcome';

      if (onboarding != 'true' && !isOnboarding) {
        return '/welcome';
      }
      if (onboarding == 'true' && isOnboarding) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),

      // Main Stateful Shell with 5 bottom navigation tabs
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainScaffold(navigationShell: navigationShell);
        },
        branches: [
          // 0: Dashboard
          StatefulShellBranch(
            navigatorKey: _shellNavigatorHomeKey,
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),

          // 1: Inventory
          StatefulShellBranch(
            navigatorKey: _shellNavigatorInventoryKey,
            routes: [
              GoRoute(
                path: '/inventory',
                builder: (context, state) {
                  final filter = state.uri.queryParameters['filter'];
                  return InventoryListScreen(initialFilter: filter);
                },
              ),
            ],
          ),

          // 2: Customers Ledger
          StatefulShellBranch(
            navigatorKey: _shellNavigatorLedgerKey,
            routes: [
              GoRoute(
                path: '/customers',
                builder: (context, state) {
                  final tab = state.uri.queryParameters['tab'];
                  return CustomersScreen(initialTab: tab);
                },
              ),
            ],
          ),

          // 3: Sales & Expenses
          StatefulShellBranch(
            navigatorKey: _shellNavigatorReportsKey,
            routes: [
              GoRoute(
                path: '/sales-expenses',
                builder: (context, state) {
                  final tab = state.uri.queryParameters['tab'];
                  return SalesAndExpensesScreen(initialTab: tab);
                },
              ),
            ],
          ),

          // 4: Settings
          StatefulShellBranch(
            navigatorKey: _shellNavigatorSettingsKey,
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),

      // Global Search
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/search',
        builder: (context, state) => const GlobalSearchScreen(),
      ),

      // Inventory Detail & Edits
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/inventory/new',
        builder: (context, state) => const AddEditMedicineScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/inventory/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return MedicineDetailScreen(medicineId: id);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/inventory/:id/edit',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return AddEditMedicineScreen(medicineId: id);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/inventory/:id/batch/new',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return AddBatchScreen(medicineId: id);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/inventory/:id/adjust',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          final batchIdStr = state.uri.queryParameters['batchId'];
          final batchId = batchIdStr != null ? int.tryParse(batchIdStr) : null;
          return InventoryAdjustmentScreen(medicineId: id, initialBatchId: batchId);
        },
      ),

      // Expiry Management
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/expiry',
        builder: (context, state) => const ExpiryManagementScreen(),
      ),

      // Reports (redirected to unified Sales & Expenses)
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/reports',
        redirect: (context, state) => '/sales-expenses',
      ),

      // Sales
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/sales',
        redirect: (context, state) => '/sales-expenses?tab=sales',
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/sales/new',
        builder: (context, state) => const NewSaleScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/sales/quick',
        builder: (context, state) => const NewSaleScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/sales/detailed',
        builder: (context, state) => const NewSaleScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/sales/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return SaleDetailScreen(saleId: id);
        },
      ),

      // Expenses
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/expenses',
        redirect: (context, state) => '/sales-expenses?tab=expenses',
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/expenses/new',
        builder: (context, state) => const AddExpenseScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/expenses/:id/edit',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return AddExpenseScreen(expenseId: id);
        },
      ),

      // Trash & Recycle Bin
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/trash',
        builder: (context, state) => const TrashScreen(),
      ),

      // Customers
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/customers/new',
        builder: (context, state) => const AddCustomerScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/customers/credit',
        builder: (context, state) => const AddCreditScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/customers/payment',
        builder: (context, state) => const RecordPaymentScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/customers/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return CustomerAccountScreen(customerId: id);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/customers/:id/edit',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return AddCustomerScreen(customerId: id);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/customers/:id/credit',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return AddCreditScreen(preselectedCustomerId: id);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/customers/:id/payment',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return RecordPaymentScreen(preselectedCustomerId: id);
        },
      ),

      // Suppliers
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/suppliers',
        builder: (context, state) => const SuppliersScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/suppliers/new',
        builder: (context, state) => const AddSupplierScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/suppliers/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return SupplierAccountScreen(supplierId: id);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/suppliers/:id/edit',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return AddSupplierScreen(supplierId: id);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/suppliers/:id/payable',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return AddSupplierPayableScreen(preselectedSupplierId: id);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/suppliers/:id/payment',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return RecordSupplierPaymentScreen(preselectedSupplierId: id);
        },
      ),

      // Notifications Center & Backup
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/notifications',
        builder: (context, state) => const NotificationCenterScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/backup',
        builder: (context, state) => const BackupRestoreScreen(),
      ),
    ],
  );
});
