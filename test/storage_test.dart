import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:organiza_financas/features/finance/data/finance_store.dart';
import 'package:organiza_financas/features/finance/data/demo_data.dart';
import 'package:organiza_financas/features/finance/domain/finance.dart';

class MemoryPreferences extends Fake implements SharedPreferencesAsync {
  final state = _PreferenceState();
  String? get value => state.value;
  bool get fail => state.fail;
  set fail(bool value) => state.fail = value;
  @override
  Future<void> setString(String key, String value) async {
    if (fail) {
      fail = false;
      throw StateError('Storage unavailable');
    }
    state.value = value;
  }
}

class _PreferenceState {
  String? value;
  bool fail = false;
}

void main() {
  test(
    'gravações em sequência preservam a última alteração e reabrem os dados',
    () async {
      final preferences = MemoryPreferences();
      final store = FinanceStore(preferences, demoData());
      final first = store.save();
      store.data.month('2026-10').withdrawal = 200000;
      final second = store.save();
      await Future.wait([first, second]);
      final reopened = FinanceData.decode(preferences.value!);
      expect(reopened.month('2026-10').withdrawal, 200000);
      expect(reopened.month('2026-10').spent('alimentacao'), 64000);
    },
  );
  test('falha de gravação é reportada e permite tentar novamente', () async {
    final preferences = MemoryPreferences()..fail = true;
    final store = FinanceStore(preferences, demoData());
    await expectLater(store.save(), throwsStateError);
    await store.save();
    expect(FinanceData.decode(preferences.value!).months.length, 1);
  });
  test('backup com valores negativos ou dias inválidos é rejeitado', () {
    final data = demoData()..reserveGoal = -1;
    expect(() => FinanceData.decode(data.encode()), throwsFormatException);
    data.reserveGoal = 10000;
    data.month('2026-10').withdrawalDay = 40;
    expect(() => FinanceData.decode(data.encode()), throwsFormatException);
  });
}
