import 'package:aquaflow_frontend/core/constants/app_strings.dart';
import 'package:aquaflow_frontend/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aquaflow_frontend/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aquaflow_frontend/features/auth/data/datasources/auth_service.dart';
import 'package:aquaflow_frontend/features/auth/data/repositories/auth_repository.dart';

void main() {
  testWidgets('LoginScreen renders header, form inputs, and Sign In button',
      (WidgetTester tester) async {
    final authNotifier = AuthNotifier(
      authRepository: AuthRepositoryImpl(authService: MockAuthService()),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(authNotifier: authNotifier),
      ),
    );

    expect(find.text(AppStrings.appTitle), findsOneWidget);
    expect(find.text('Operator Sign In'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('LoginScreen shows validation errors on empty submission',
      (WidgetTester tester) async {
    final authNotifier = AuthNotifier(
      authRepository: AuthRepositoryImpl(authService: MockAuthService()),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(authNotifier: authNotifier),
      ),
    );

    await tester.ensureVisible(find.text('Sign In'));
    await tester.tap(find.text('Sign In'));
    await tester.pump();

    expect(find.text('Please enter your username or email'), findsOneWidget);
    expect(find.text('Please enter your password'), findsOneWidget);
  });

  testWidgets('LoginScreen displays error banner on failed login',
      (WidgetTester tester) async {
    final authNotifier = AuthNotifier(
      authRepository: AuthRepositoryImpl(authService: MockAuthService()),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(authNotifier: authNotifier),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'operator');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrongpassword');
    await tester.ensureVisible(find.text('Sign In'));
    await tester.tap(find.text('Sign In'));
    await tester.pump(); // Start authenticating
    await tester.pump(const Duration(milliseconds: 700)); // Finish auth call

    expect(find.text('Invalid username or password.'), findsOneWidget);
  });
}
