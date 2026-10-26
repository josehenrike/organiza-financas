import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:organiza_financas/core/theme/app_theme.dart';
import 'package:organiza_financas/features/finance/data/demo_data.dart';
import 'package:organiza_financas/features/finance/data/finance_store.dart';
import 'package:organiza_financas/features/finance/domain/finance.dart';
import 'package:organiza_financas/features/finance/presentation/finance_home.dart';
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
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
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
    expect(find.text('Padaria teste'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('formulário rejeita valor inválido e cadastra renda', (
    tester,
  ) async {
    final data = FinanceData();
    await open(tester, data);
    await tester.ensureVisible(find.text('Adicionar renda').first);
    await tester.tap(find.text('Adicionar renda').first);
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
}
