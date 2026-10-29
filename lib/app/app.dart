import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/finance/data/finance_store.dart';
import '../features/finance/presentation/finance_home.dart';
import '../features/finance/presentation/finance_widgets.dart';

class OrganizaFinancasApp extends StatelessWidget {
  const OrganizaFinancasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Organiza Finanças',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: SupabaseConfig.configured
          ? const _AuthGate()
          : const _MissingConfig(),
    );
  }
}

/// Mostra o login sem sessão e os dados da conta quando há sessão.
class _AuthGate extends StatelessWidget {
  const _AuthGate();
  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, _) {
        final user = auth.currentUser;
        if (user == null) return LoginPage(auth: auth);
        return _Startup(key: ValueKey(user.id), userId: user.id);
      },
    );
  }
}

class _MissingConfig extends StatelessWidget {
  const _MissingConfig();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Banco de dados não configurado.\n\n'
          'Copie supabase.example.json para supabase.json, preencha com os '
          'dados do seu projeto Supabase e rode:\n'
          'flutter run --dart-define-from-file=supabase.json',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

class _Startup extends StatefulWidget {
  const _Startup({super.key, required this.userId});
  final String userId;
  @override
  State<_Startup> createState() => _StartupState();
}

class _StartupState extends State<_Startup> {
  late final remote = SupabaseFinanceRemote(
    Supabase.instance.client,
    widget.userId,
  );
  late Future<FinanceStore> future = open();

  Future<FinanceStore> open() =>
      FinanceStore.open(remote: remote, userId: widget.userId);

  Future<void> signOut(FinanceStore store) async {
    if (!await confirm(
      context,
      'Sair da conta?',
      store.pendingSync
          ? 'Algumas alterações ainda não foram enviadas para a nuvem. Elas '
                'ficam guardadas neste aparelho e serão enviadas quando você '
                'entrar de novo com internet.'
          : 'Seus dados continuam salvos na sua conta.',
      action: 'Sair',
    )) {
      return;
    }
    await Supabase.instance.client.auth.signOut();
  }

  Future<void> copyRaw() async {
    final raw = await FinanceStore.readRaw(userId: widget.userId);
    await Clipboard.setData(ClipboardData(text: raw ?? ''));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dados copiados. Cole em um arquivo e guarde.'),
      ),
    );
  }

  Future<void> startOver() async {
    if (!await confirm(
      context,
      'Começar do zero?',
      'Uma cópia dos dados atuais fica guardada no dispositivo, mas o app '
          'abrirá vazio. Copie os dados antes, se quiser recuperá-los depois.',
      action: 'Começar do zero',
      destructive: true,
    )) {
      return;
    }
    setState(
      () => future = FinanceStore.startOver(
        remote: remote,
        userId: widget.userId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<FinanceStore>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        final store = snapshot.data!;
        return FinanceHome(store: store, onSignOut: () => signOut(store));
      }
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: snapshot.hasError
                ? ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.storage_outlined, size: 48),
                        const SizedBox(height: 16),
                        const Text(
                          'Não foi possível abrir os dados salvos. '
                          'Seus dados não foram apagados.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: () => setState(() => future = open()),
                          child: const Text('Tentar novamente'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: copyRaw,
                          icon: const Icon(Icons.copy_outlined),
                          label: const Text('Copiar dados salvos'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: startOver,
                          child: const Text('Começar do zero'),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: context.colors.businessFill,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(
                          Icons.spa_outlined,
                          color: Colors.white,
                          size: 52,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Organiza Finanças',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 120,
                        child: LinearProgressIndicator(
                          color: context.colors.business,
                          backgroundColor: context.colors.track,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      );
    },
  );
}
