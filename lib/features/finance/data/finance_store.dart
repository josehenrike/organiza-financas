import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/finance.dart';

class FinanceStore extends ChangeNotifier {
  FinanceStore(this.preferences, this.data);
  final SharedPreferencesAsync preferences;
  FinanceData data;
  static const storageKey = 'agricultura_financas_v1';
  static const recoveryKey = '${storageKey}_recuperacao';
  Future<void> _pending = Future.value();
  static Future<FinanceStore> open() async {
    final preferences = SharedPreferencesAsync();
    final raw = await preferences.getString(storageKey);
    return FinanceStore(
      preferences,
      raw == null ? FinanceData() : FinanceData.decode(raw),
    );
  }

  /// Conteúdo gravado sem interpretar, para recuperar dados que não abrem.
  static Future<String?> readRaw() =>
      SharedPreferencesAsync().getString(storageKey);

  /// Guarda uma cópia dos dados ilegíveis e começa vazio.
  static Future<FinanceStore> startOver() async {
    final preferences = SharedPreferencesAsync();
    final raw = await preferences.getString(storageKey);
    if (raw != null) await preferences.setString(recoveryKey, raw);
    await preferences.remove(storageKey);
    return FinanceStore(preferences, FinanceData());
  }

  Future<void> save() {
    final snapshot = data.encode();
    notifyListeners();
    final write = _pending.then(
      (_) => preferences.setString(storageKey, snapshot),
    );
    _pending = write.catchError((Object _) {});
    return write;
  }
}
