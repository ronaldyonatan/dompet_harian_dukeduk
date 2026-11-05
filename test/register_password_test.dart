import 'package:dompet_harian_dukeduk/screens/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> openRegistration(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: RegisterScreen(languageCode: 'id')),
    );
  }

  testWidgets('both passwords have independent visibility controls', (
    tester,
  ) async {
    await openRegistration(tester);
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(4));
    await tester.enterText(fields.at(2), 'Rahasia123!');
    await tester.enterText(fields.at(3), 'Rahasia123!');
    expect(tester.widget<TextField>(fields.at(2)).obscureText, isTrue);
    expect(tester.widget<TextField>(fields.at(3)).obscureText, isTrue);

    final show = find.byTooltip('Tampilkan password');
    await tester.ensureVisible(show);
    await tester.tap(show);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(fields.at(2)).obscureText, isFalse);
    expect(tester.widget<TextField>(fields.at(3)).obscureText, isTrue);

    final confirm = find.byTooltip('Tampilkan konfirmasi password');
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(fields.at(3)).obscureText, isFalse);
    expect(find.text('Password sudah sama.'), findsOneWidget);
  });

  testWidgets('mismatched passwords block registration before Firebase', (
    tester,
  ) async {
    await openRegistration(tester);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Penguji');
    await tester.enterText(fields.at(1), 'penguji@example.com');
    await tester.enterText(fields.at(2), 'Rahasia123!');
    await tester.enterText(fields.at(3), 'Berbeda123!');
    final submit = find.text('Daftar Sekarang');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Konfirmasi password belum sama.'), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    await tester.enterText(fields.at(3), 'Rahasia123!');
    await tester.pumpAndSettle();
    expect(find.text('Password sudah sama.'), findsOneWidget);
    await tester.enterText(fields.at(2), 'PasswordBaru123!');
    await tester.pumpAndSettle();
    expect(find.text('Password sudah sama.'), findsNothing);
    expect(find.text('Konfirmasi password belum sama.'), findsWidgets);
  });
}
