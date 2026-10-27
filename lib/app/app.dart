import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/theme/app_theme.dart';
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
      home: const _Startup(),
    );
  }
}

class _Startup extends StatefulWidget {
  const _Startup();
  @override
  State<_Startup> createState() => _StartupState();
}

class _StartupState extends State<_Startup> {
  late Future<FinanceStore> future = FinanceStore.open();

  Future<void> copyRaw() async {
    final raw = await FinanceStore.readRaw();
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
    setState(() => future = FinanceStore.startOver());
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<FinanceStore>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasData) return FinanceHome(store: snapshot.data!);
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
                          onPressed: () =>
                              setState(() => future = FinanceStore.open()),
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
