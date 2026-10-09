import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arslan_medical_store/core/widgets/metric_card.dart';
import 'package:arslan_medical_store/core/widgets/status_chip.dart';
import 'package:arslan_medical_store/core/widgets/app_text_field.dart';
import 'package:arslan_medical_store/core/theme/app_colors.dart';

void main() {
  testWidgets('MetricCard displays title, value and subtitle', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MetricCard(
            title: "Today's Sales",
            value: 'Rs. 15,400',
            subtitle: '12 orders today',
            icon: Icons.point_of_sale,
            accentColor: AppColors.primary,
          ),
        ),
      ),
    );

    expect(find.text("Today's Sales"), findsOneWidget);
    expect(find.text('Rs. 15,400'), findsOneWidget);
    expect(find.text('12 orders today'), findsOneWidget);
  });

  testWidgets('StatusChip renders label and icon correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatusChip(
            label: 'Expired',
            type: StatusType.expired,
            icon: Icons.warning_amber_rounded,
          ),
        ),
      ),
    );

    expect(find.text('Expired'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('AppTextField accepts input and validates correctly', (WidgetTester tester) async {
    final controller = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppTextField(
            label: 'Medicine Name',
            controller: controller,
            hint: 'e.g. Panadol 500mg',
          ),
        ),
      ),
    );

    expect(find.text('Medicine Name'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Augmentin 625mg');
    expect(controller.text, 'Augmentin 625mg');
  });
}
