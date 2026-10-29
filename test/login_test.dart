import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:organiza_financas/core/theme/app_theme.dart';
import 'package:organiza_financas/features/auth/presentation/login_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeAuth extends Fake implements GoTrueClient {
  final verified = <String>[];
  var resent = 0;
  @override
  Future<AuthResponse> signUp({
    String? email,
    String? phone,
    required String password,
    String? emailRedirectTo,
    Map<String, dynamic>? data,
    String? captchaToken,
    OtpChannel channel = OtpChannel.sms,
  }) async => AuthResponse();
  @override
  Future<AuthResponse> signInWithPassword({
    String? email,
    String? phone,
    required String password,
    String? captchaToken,
  }) async =>
      throw AuthException('Email not confirmed', code: 'email_not_confirmed');
  @override
  Future<AuthResponse> verifyOTP({
    String? email,
    String? phone,
    String? token,
    required OtpType type,
    String? redirectTo,
    String? captchaToken,
    String? tokenHash,
  }) async {
    verified.add('$email:$token:${type.name}');
    return AuthResponse();
  }

  @override
  Future<ResendResponse> resend({
    String? email,
    String? phone,
    required OtpType type,
    String? emailRedirectTo,
    String? captchaToken,
  }) async {
    resent++;
    return ResendResponse();
  }
}

void main() {
  Future<FakeAuth> open(WidgetTester tester) async {
    final auth = FakeAuth();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LoginPage(auth: auth),
      ),
    );
    return auth;
  }

  Future<void> fill(WidgetTester tester) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-mail'),
      'ana@exemplo.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Senha'),
      'segredo1',
    );
  }

  testWidgets('conta nova é confirmada com o código do e-mail', (tester) async {
    final auth = await open(tester);
    await tester.tap(find.text('Não tenho conta: criar agora'));
    await tester.pump();
    await fill(tester);
    await tester.tap(find.text('Criar conta'));
    await tester.pumpAndSettle();
    expect(find.text('Confirme seu e-mail'), findsOneWidget);
    expect(find.textContaining('ana@exemplo.com'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Código do e-mail'),
      '123456',
    );
    await tester.ensureVisible(find.text('Confirmar código'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar código'));
    await tester.pumpAndSettle();
    expect(auth.verified, ['ana@exemplo.com:123456:signup']);
  });

  testWidgets('entrar sem confirmar oferece enviar um código', (tester) async {
    final auth = await open(tester);
    await fill(tester);
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Confirme seu e-mail'), findsOneWidget);
    await tester.ensureVisible(find.text('Enviar código'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enviar código'));
    await tester.pumpAndSettle();
    expect(auth.resent, 1);
    expect(find.textContaining('Enviamos um código'), findsOneWidget);
  });
}
