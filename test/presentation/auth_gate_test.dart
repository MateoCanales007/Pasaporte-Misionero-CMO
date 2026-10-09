import 'package:flutter_test/flutter_test.dart';
import 'package:pasaporte_misionero_cmo/app.dart';
import 'package:pasaporte_misionero_cmo/presentation/screens/auth/auth_screen.dart';
import 'package:pasaporte_misionero_cmo/presentation/screens/home/home_screen.dart';

import '../helpers/test_app.dart';

/// Regresión: la primera pantalla nunca debe quedarse en el fondo azul de carga.
void main() {
  setUpAll(initTestLocale);

  testWidgets('sin sesión muestra el inicio de sesión', (tester) async {
    await pumpTestApp(tester, const AuthGate(), TestDeps(signedIn: false));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AuthScreen), findsOneWidget);
  });

  testWidgets('con sesión y pasaporte entra a la pantalla principal', (tester) async {
    await pumpTestApp(tester, const AuthGate(), TestDeps());
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('ESCANEAR SELLO'), findsOneWidget);
  });
}
