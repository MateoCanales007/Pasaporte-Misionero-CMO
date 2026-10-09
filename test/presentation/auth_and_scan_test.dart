import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasaporte_misionero_cmo/core/errors/app_exception.dart';
import 'package:pasaporte_misionero_cmo/domain/models/qr_models.dart';
import 'package:pasaporte_misionero_cmo/presentation/screens/auth/auth_screen.dart';
import 'package:pasaporte_misionero_cmo/presentation/screens/qr/redemption_result_view.dart';

import '../helpers/test_app.dart';

/// flutter_login anima su tarjeta en varias etapas: se avanzan varios frames.
Future<void> settleLogin(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  setUpAll(initTestLocale);

  group('Inicio de sesión', () {
    testWidgets('muestra los textos en español', (tester) async {
      await pumpTestApp(tester, const AuthScreen(), TestDeps());
      await settleLogin(tester);
      expect(find.text('INICIAR SESIÓN'), findsOneWidget);
      expect(find.text('Nombre de usuario'), findsOneWidget);
      expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
    });

    testWidgets('envía usuario y contraseña al repositorio', (tester) async {
      final deps = TestDeps()..auth.loginResult = 'Usuario o contraseña incorrectos.';
      await pumpTestApp(tester, const AuthScreen(), deps);
      await settleLogin(tester);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'maria');
      await tester.enterText(fields.at(1), 'secreto123');
      await tester.tap(find.text('INICIAR SESIÓN'));
      await settleLogin(tester);

      expect(deps.auth.loginCalls, [('maria', 'secreto123')]);
      await settleLogin(tester);
    });

    testWidgets('valida campos vacíos sin llamar al repositorio', (tester) async {
      final deps = TestDeps();
      await pumpTestApp(tester, const AuthScreen(), deps);
      await settleLogin(tester);
      await tester.tap(find.text('INICIAR SESIÓN'));
      await settleLogin(tester);
      expect(find.text('Escribe tu nombre de usuario'), findsOneWidget);
      expect(deps.auth.loginCalls, isEmpty);
      await settleLogin(tester);
    });
  });

  group('Resultado del escaneo', () {
    Future<void> pumpResult(WidgetTester tester, ScanOutcome outcome) =>
        pumpTestApp(tester, RedemptionResultView(outcome: outcome, onScanAgain: () {}, onClose: () {}), TestDeps());

    testWidgets('sello confirmado por el servidor', (tester) async {
      await pumpResult(
        tester,
        const ScanOutcome.result(RedemptionConfirmed(missionId: 'm1', missionName: 'Guatemala')),
      );
      expect(find.text('¡Sello obtenido!'), findsOneWidget);
      expect(find.textContaining('Guatemala'), findsOneWidget);
    });

    testWidgets('sin conexión: pendiente de validación, nunca confirmado', (tester) async {
      await pumpResult(tester, const ScanOutcome.result(RedemptionQueued()));
      expect(find.textContaining('pendiente de validación'), findsOneWidget);
      expect(find.textContaining('Todavía no es un sello confirmado'), findsOneWidget);
      expect(find.text('¡Sello obtenido!'), findsNothing);
    });

    testWidgets('código vencido o antiguo invita a volver a escanear', (tester) async {
      await pumpResult(tester, const ScanOutcome.result(RedemptionExpired()));
      expect(find.text('El código venció'), findsOneWidget);
      expect(find.text('Escanear de nuevo'), findsOneWidget);

      await pumpResult(tester, const ScanOutcome.result(RedemptionInvalid(isLegacyCode: true)));
      expect(find.textContaining('antiguo'), findsOneWidget);
    });

    testWidgets('los errores internos no se muestran al usuario', (tester) async {
      await pumpResult(tester, ScanOutcome.error(StateError('NullPointer en línea 42')));
      expect(find.textContaining('NullPointer'), findsNothing);
      expect(find.text(const UnknownException().message), findsOneWidget);
    });
  });
}
