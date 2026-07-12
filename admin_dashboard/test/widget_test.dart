import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_dashboard/core/theme/admin_theme.dart';
import 'package:admin_dashboard/main.dart';

void main() {
  testWidgets('renders admin login screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AdminTheme.dark(),
        home: const AdminLoginScreen(),
      ),
    );

    expect(find.text('Admin Sign In'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
