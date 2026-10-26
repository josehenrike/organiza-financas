import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/finance.dart';

class FinanceStore extends ChangeNotifier {
  FinanceStore(this.preferences, this.data);
  final SharedPreferencesAsync preferences;
  FinanceData data;
  static const storageKey = 'agricultura_financas_v1';
  Future<void> _pending = Future.value();
  static Future<FinanceStore> open() async {
    final preferences = SharedPreferencesAsync();
    final raw = await preferences.getString(storageKey);
    return FinanceStore(
      preferences,
      raw == null ? FinanceData() : FinanceData.decode(raw),
    );
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
