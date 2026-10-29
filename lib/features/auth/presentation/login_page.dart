import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../finance/presentation/finance_widgets.dart';

/// Entrar ou criar conta com e-mail e senha. Contas novas são confirmadas
/// com o código enviado por e-mail, digitado no próprio app.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.auth});
  final GoTrueClient auth;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  final code = TextEditingController();
  bool creating = false, busy = false, hidden = true;

  /// Aguardando o código de confirmação enviado para [email].
  bool confirming = false;
  String? message;
  bool messageIsError = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    code.dispose();
    super.dispose();
  }

  static String describe(Object error) {
    if (error is AuthException) {
      return switch (error.code) {
        'invalid_credentials' => 'E-mail ou senha incorretos.',
        'otp_expired' =>
          'Código errado ou vencido. Confira o último e-mail ou peça outro código.',
        'user_already_exists' || 'email_exists' =>
          'Já existe uma conta com este e-mail. Toque em Entrar.',
        'weak_password' => 'Senha fraca. Use pelo menos 6 caracteres.',
        'over_email_send_rate_limit' || 'over_request_rate_limit' =>
          'Muitas tentativas. Aguarde alguns minutos e tente de novo.',
        _ => 'Não foi possível continuar. Tente novamente.',
      };
    }
    return 'Sem conexão. Verifique a internet e tente novamente.';
  }

  /// Mostra a etapa do código. [sent] diz se o e-mail acabou de sair.
  void askCode({required bool sent}) => setState(() {
    confirming = true;
    code.clear();
    messageIsError = false;
    message = sent
        ? 'Enviamos um código para ${email.text.trim()}. Digite-o abaixo.'
        : 'Seu e-mail ainda não foi confirmado. Toque em “Enviar código” '
              'para receber um código em ${email.text.trim()}.';
  });

  Future<void> run(Future<void> Function() action) async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      if (e is AuthException && e.code == 'email_not_confirmed') {
        askCode(sent: false);
      } else {
        setState(() {
          messageIsError = true;
          message = describe(e);
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit() => run(() async {
    if (creating) {
      final result = await widget.auth.signUp(
        email: email.text.trim(),
        password: password.text,
      );
      // Com confirmação de e-mail ligada, a sessão só vem depois do código.
      if (result.session == null && mounted) askCode(sent: true);
    } else {
      await widget.auth.signInWithPassword(
        email: email.text.trim(),
        password: password.text,
      );
    }
  });

  Future<void> verify() => run(
    () => widget.auth.verifyOTP(
      email: email.text.trim(),
      token: code.text.trim(),
      type: OtpType.signup,
    ),
  );

  Future<void> resend() async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await widget.auth.resend(email: email.text.trim(), type: OtpType.signup);
      if (mounted) askCode(sent: true);
    } catch (e) {
      if (mounted) {
        setState(() {
          messageIsError = true;
          message = describe(e);
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget progressOr(String label) => busy
      ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : Text(label);

  List<Widget> credentials() => [
    TextFormField(
      controller: email,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(labelText: 'E-mail'),
      validator: (s) =>
          s == null || !RegExp(r'^\S+@\S+\.\S+$').hasMatch(s.trim())
          ? 'Informe um e-mail válido'
          : null,
    ),
    const SizedBox(height: 16),
    TextFormField(
      controller: password,
      obscureText: hidden,
      autofillHints: [
        creating ? AutofillHints.newPassword : AutofillHints.password,
      ],
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => submit(),
      decoration: InputDecoration(
        labelText: 'Senha',
        helperText: creating ? 'Pelo menos 6 caracteres' : null,
        suffixIcon: IconButton(
          tooltip: hidden ? 'Mostrar senha' : 'Esconder senha',
          onPressed: () => setState(() => hidden = !hidden),
          icon: Icon(hidden ? Icons.visibility : Icons.visibility_off),
        ),
      ),
      validator: (s) =>
          (s ?? '').length < 6 ? 'Use pelo menos 6 caracteres' : null,
    ),
  ];

  List<Widget> credentialActions() => [
    FilledButton(
      onPressed: busy ? null : submit,
      child: progressOr(creating ? 'Criar conta' : 'Entrar'),
    ),
    const SizedBox(height: 8),
    TextButton(
      onPressed: busy
          ? null
          : () => setState(() {
              creating = !creating;
              message = null;
            }),
      child: Text(
        creating ? 'Já tenho conta: entrar' : 'Não tenho conta: criar agora',
      ),
    ),
  ];

  List<Widget> codeStep() => [
    TextFormField(
      controller: code,
      keyboardType: TextInputType.number,
      autofillHints: const [AutofillHints.oneTimeCode],
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 24,
        letterSpacing: 6,
        fontWeight: FontWeight.w700,
      ),
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => verify(),
      decoration: const InputDecoration(labelText: 'Código do e-mail'),
      validator: (s) =>
          (s ?? '').length < 6 ? 'Digite o código que chegou no e-mail' : null,
    ),
  ];

  List<Widget> codeActions() => [
    FilledButton(
      onPressed: busy ? null : verify,
      child: progressOr('Confirmar código'),
    ),
    const SizedBox(height: 8),
    OutlinedButton.icon(
      onPressed: busy ? null : resend,
      icon: const Icon(Icons.forward_to_inbox_outlined),
      label: const Text('Enviar código'),
    ),
    const SizedBox(height: 8),
    TextButton(
      onPressed: busy
          ? null
          : () => setState(() {
              confirming = false;
              creating = false;
              message = null;
            }),
      child: const Text('Voltar'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: form,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: c.businessFill,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.spa_outlined,
                            color: Colors.white,
                            size: 42,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        confirming
                            ? 'Confirme seu e-mail'
                            : 'Organiza Finanças',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        confirming
                            ? 'O código chega em alguns instantes. Confira também a caixa de spam.'
                            : creating
                            ? 'Crie sua conta para guardar seus dados com segurança.'
                            : 'Entre para ver suas finanças em qualquer aparelho.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.muted),
                      ),
                      const SizedBox(height: 24),
                      ...confirming ? codeStep() : credentials(),
                      if (message != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Notice(
                            message!,
                            icon: messageIsError
                                ? Icons.error_outline
                                : Icons.mark_email_read_outlined,
                            warning: messageIsError,
                          ),
                        ),
                      const SizedBox(height: 24),
                      ...confirming ? codeActions() : credentialActions(),
                      const SizedBox(height: 16),
                      const AppVersion(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
