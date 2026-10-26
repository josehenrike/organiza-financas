import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/theme/app_theme.dart';
import '../features/finance/data/finance_store.dart';
import '../features/finance/presentation/finance_home.dart';

class OrganizaFinancasApp extends StatelessWidget {
  const OrganizaFinancasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Organiza Finanças',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
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
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.storage_outlined, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Não foi possível abrir os dados salvos. Seus dados não foram apagados.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () =>
                            setState(() => future = FinanceStore.open()),
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  )
                : const CircularProgressIndicator(),
          ),
        ),
      );
    },
  );
}
