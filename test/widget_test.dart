import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:organiza_financas/core/theme/app_theme.dart';
import 'demo_data.dart';
import 'package:organiza_financas/features/finance/data/finance_store.dart';
import 'package:organiza_financas/features/finance/domain/finance.dart';
import 'package:organiza_financas/features/finance/presentation/finance_home.dart';
import 'package:organiza_financas/features/finance/presentation/finance_widgets.dart';
import 'package:organiza_financas/features/finance/presentation/item_form.dart';

class MemoryStore extends FinanceStore {
  MemoryStore(FinanceData data) : super(FakePreferences(), data);
  @override
  Future<void> save() async {
    notifyListeners();
  }
}

class FakePreferences extends Fake implements SharedPreferencesAsync {}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    PackageInfo.setMockInitialValues(
      appName: 'Organiza Finanças',
      packageName: 'com.example.organiza_financas',
      version: '1.1.3',
      buildNumber: '5',
      buildSignature: '',
    );
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    var sdk = File(Platform.resolvedExecutable).parent;
    for (var i = 0; i < 5; i++) {
      sdk = sdk.parent;
    }
    final font = File(
      '${sdk.path}/engine/src/flutter/txt/third_party/fonts/Roboto-Regular.ttf',
    );
    if (font.existsSync()) {
      final loader = FontLoader('Roboto')
        ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
      await loader.load();
    }
  });
  Future<void> open(
    WidgetTester tester,
    FinanceData data, {
    Size size = const Size(390, 844),
    double scale = 1,
    ThemeMode mode = ThemeMode.light,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        locale: const Locale('pt', 'BR'),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('pt', 'BR')],
        builder: (context, child) => RepaintBoundary(
          key: const ValueKey('screen'),
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
        home: FinanceHome(store: MemoryStore(data)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('screen')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('tmp/screenshots').create(recursive: true);
      await File(
        'tmp/screenshots/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('navegação em celular sem overflow e screenshots', (
    tester,
  ) async {
    await open(tester, demoData());
    await capture(tester, 'cadastro-mobile');
    for (final label in ['Negócio', 'Família', 'Agenda', 'Resultado']) {
      await tester.tap(find.widgetWithText(NavigationDestination, label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture(
        tester,
        'mobile-${label == 'Negócio'
            ? 'negocio'
            : label == 'Família'
            ? 'familia'
            : label.toLowerCase()}',
      );
    }
  });
  testWidgets('limite registra gasto e atualiza saldo', (tester) async {
    final data = demoData();
    await open(tester, data);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Família'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alimentação').first);
    await tester.pumpAndSettle();
    await capture(tester, 'limite-mobile');
    await tester.enterText(find.byType(TextFormField).at(0), 'Padaria teste');
    await tester.enterText(find.byType(TextFormField).at(1), '50,25');
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Salvar gasto'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar gasto'));
    await tester.pumpAndSettle();
    expect(data.month('2026-10').spent('alimentacao'), 69025);
    expect(find.widgetWithText(ListTile, 'Padaria teste'), findsOneWidget);
    // Editar o gasto pelo histórico.
    await tester.tap(find.widgetWithText(ListTile, 'Padaria teste'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(1), '60');
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Salvar alteração'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar alteração'));
    await tester.pumpAndSettle();
    expect(data.month('2026-10').spent('alimentacao'), 70000);
    expect(tester.takeException(), isNull);
  });
  testWidgets('formulário rejeita valor inválido e cadastra renda', (
    tester,
  ) async {
    final data = FinanceData();
    await open(tester, data);
    await tester.ensureVisible(find.text('Adicionar renda').first);
    // Toca na borda esquerda: o botão flutuante fica à direita.
    final add = find.widgetWithText(OutlinedButton, 'Adicionar renda').first;
    await tester.tapAt(
      tester.getTopLeft(add) + Offset(24, tester.getSize(add).height / 2),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();
    expect(find.text('Informe um valor maior que zero'), findsOneWidget);
    await tester.enterText(
      find
          .descendant(
            of: find.byType(ItemForm),
            matching: find.byType(TextFormField),
          )
          .at(0),
      'Venda da horta',
    );
    await tester.enterText(
      find
          .descendant(
            of: find.byType(ItemForm),
            matching: find.byType(TextFormField),
          )
          .at(1),
      '1500,50',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();
    expect(
      data.month(monthKey(DateTime.now())).income(Pocket.business),
      150050,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('com o teclado aberto os campos continuam visíveis', (
    tester,
  ) async {
    await open(tester, FinanceData());
    final add = find.widgetWithText(OutlinedButton, 'Adicionar renda').first;
    await tester.ensureVisible(add);
    await tester.tapAt(
      tester.getTopLeft(add) + Offset(24, tester.getSize(add).height / 2),
    );
    await tester.pumpAndSettle();
    // Teclado do celular ocupando 340 px da parte de baixo da tela.
    tester.view.viewInsets = const FakeViewPadding(bottom: 340);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    final keyboardTop = tester.view.physicalSize.height - 340;
    final fields = find.descendant(
      of: find.byType(ItemForm),
      matching: find.byType(TextFormField),
    );
    for (final i in [0, 1]) {
      final rect = tester.getRect(fields.at(i));
      expect(rect.top, greaterThan(0));
      expect(rect.bottom, lessThan(keyboardTop));
    }
    final save = tester.getRect(find.widgetWithText(FilledButton, 'Salvar'));
    expect(save.bottom, lessThanOrEqualTo(keyboardTop));
    expect(save.top, greaterThan(tester.getRect(fields.at(1)).bottom));
  });
  testWidgets('desktop e texto ampliado mantêm navegação utilizável', (
    tester,
  ) async {
    await open(tester, demoData(), size: const Size(1440, 1000));
    expect(find.byType(NavigationRail), findsOneWidget);
    await capture(tester, 'desktop');
    expect(tester.takeException(), isNull);
    await open(tester, demoData(), size: const Size(360, 800), scale: 1.4);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Agenda'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('navegar entre meses não cria meses salvos', (tester) async {
    final data = demoData();
    await open(tester, data);
    await tester.tap(find.byTooltip('Próximo mês'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Próximo mês'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Mês ainda não iniciado'), findsOneWidget);
    await tester.tap(find.byTooltip('Mês anterior'));
    await tester.pumpAndSettle();
    expect(data.months.keys, ['2026-10']);
    expect(tester.takeException(), isNull);
  });
  testWidgets('botão de gasto rápido abre a categoria escolhida', (
    tester,
  ) async {
    await open(tester, demoData());
    await tester.tap(find.text('Registrar gasto'));
    await tester.pumpAndSettle();
    expect(find.text('Onde foi o gasto?'), findsOneWidget);
    await capture(tester, 'gasto-rapido-mobile');
    await tester.tap(find.widgetWithText(ListTile, 'Combustível'));
    await tester.pumpAndSettle();
    expect(find.text('Ainda pode gastar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('registrar depósito soma a reserva do mês', (tester) async {
    final data = demoData();
    await open(tester, data);
    final button = find.text('Já guardei');
    await tester.scrollUntilVisible(
      button,
      300,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(data.reserveSaved, 85000);
    expect(data.month('2026-10').reserveDeposited, isTrue);
    await tester.tap(find.text('Desfazer').first);
    await tester.pumpAndSettle();
    expect(data.reserveSaved, 65000);
  });
  testWidgets('registra várias retiradas no mesmo mês', (tester) async {
    final data = demoData();
    await open(tester, data);
    final button = find.text('Registrar retirada');
    for (final value in ['30', '45,50']) {
      await tester.scrollUntilVisible(
        button,
        300,
        scrollable: find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, value);
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
    }
    final m = data.month('2026-10');
    expect(m.withdrawals.length, 5);
    expect(m.withdrawal, 250000 + 3000 + 4550);
    expect(find.text('5 retiradas neste mês'), findsWidgets);
  });
  testWidgets('ícone de informação explica a retirada', (tester) async {
    await open(tester, demoData());
    final info = find.byTooltip('Saiba mais: A ponte entre a roça e a casa');
    await tester.scrollUntilVisible(
      info,
      300,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(info);
    await tester.pumpAndSettle();
    await tester.tap(info);
    await tester.pumpAndSettle();
    expect(find.textContaining('mesmo valores pequenos'), findsOneWidget);
    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();
    expect(find.text('Entendi'), findsNothing);
  });
  testWidgets('informação longa rola em tela pequena', (tester) async {
    await open(tester, demoData(), size: const Size(360, 640), scale: 1.6);
    final info = find.byTooltip('Saiba mais: Reserva do negócio').first;
    await tester.scrollUntilVisible(
      info,
      300,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(info);
    await tester.pumpAndSettle();
    await tester.tap(info);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final text = find.textContaining('toque em “Já guardei”');
    // Sem rolagem o Flutter só corta o texto, sem erro: exige a rolagem.
    final scroll = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(Scrollable),
    );
    expect(scroll, findsOneWidget);
    await tester.dragFrom(
      tester.getCenter(find.byType(AlertDialog)),
      const Offset(0, -2000),
    );
    await tester.pumpAndSettle();
    // O fim do texto chega acima do botão, que continua fixo e tocável.
    final ok = tester.getRect(find.text('Entendi'));
    expect(tester.getRect(text).bottom, lessThanOrEqualTo(ok.top));
    expect(ok.bottom, lessThanOrEqualTo(640));
    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();
    expect(find.text('Entendi'), findsNothing);
  });
  testWidgets('rodapé mostra a versão instalada', (tester) async {
    await open(tester, FinanceData());
    final version = find.text('Versão 1.1.3 (5)');
    await tester.scrollUntilVisible(
      version,
      300,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(version, findsOneWidget);
  });
  testWidgets('tema escuro renderiza as cinco áreas', (tester) async {
    await open(tester, demoData(), mode: ThemeMode.dark);
    await capture(tester, 'dark-cadastro');
    for (final label in ['Negócio', 'Família', 'Agenda', 'Resultado']) {
      await tester.tap(find.widgetWithText(NavigationDestination, label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await capture(tester, 'dark-resultado');
  });
  testWidgets('app vazio mostra os primeiros passos', (tester) async {
    await open(tester, FinanceData());
    expect(find.text('Vamos começar'), findsOneWidget);
    expect(find.text('Conhecer o app com exemplos'), findsNothing);
    expect(find.byTooltip('Opções e cópia de segurança'), findsNothing);
    await capture(tester, 'vazio-mobile');
  });
  testWidgets('seletor de mês pula direto para o mês escolhido', (
    tester,
  ) async {
    final data = demoData();
    data.month('2026-11');
    await open(tester, data);
    await tester.tap(find.byTooltip('Escolher mês'));
    await tester.pumpAndSettle();
    await capture(tester, 'seletor-mes-mobile');
    await tester.tap(find.text('Mar'));
    await tester.pumpAndSettle();
    expect(find.text('Março de 2026'), findsOneWidget);
    expect(find.text('Hoje'), findsOneWidget);
    expect(data.months.keys, containsAll(['2026-10', '2026-11']));
    expect(data.months.length, 2);
  });
  testWidgets('capturas do formulário, resultado e desktop', (tester) async {
    final data = demoData();
    data.month('2026-09')
      ..items.addAll(data.month('2026-10').items)
      ..spending.add(
        Spending(
          id: 's',
          itemId: 'insumos',
          description: 'Ração',
          amount: 400000,
          date: DateTime(2026, 9, 3),
        ),
      );
    await open(tester, data);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Resultado'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byType(BalanceChart),
      300,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, 'mobile-grafico');
    await tester.tap(find.widgetWithText(NavigationDestination, 'Cadastro'));
    await tester.pumpAndSettle();
    final add = find.widgetWithText(OutlinedButton, 'Adicionar renda').first;
    await tester.tapAt(
      tester.getTopLeft(add) + Offset(24, tester.getSize(add).height / 2),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    await capture(tester, 'form-mobile');
    await tester.tap(find.byTooltip('Cancelar'));
    await tester.pumpAndSettle();
    await open(tester, demoData(), size: const Size(1440, 1000));
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('Negócio'),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, 'desktop-negocio');
    expect(tester.takeException(), isNull);
  });
}
