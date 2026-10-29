import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/finance.dart';

/// Onde os dados ficam guardados fora do aparelho.
abstract class FinanceRemote {
  /// JSON salvo na nuvem, ou nulo se o usuário ainda não tem dados lá.
  Future<String?> load();
  Future<void> save(String json);
}

/// Uma linha por usuário na tabela `finance_data`, protegida por RLS.
class SupabaseFinanceRemote implements FinanceRemote {
  SupabaseFinanceRemote(this.client, this.userId);
  final SupabaseClient client;
  final String userId;
  static const table = 'finance_data';

  @override
  Future<String?> load() async {
    final row = await client
        .from(table)
        .select('data')
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? null : jsonEncode(row['data']);
  }

  @override
  Future<void> save(String json) => client.from(table).upsert({
    'user_id': userId,
    'data': jsonDecode(json),
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  });
}

/// Guarda os dados no aparelho e, quando há conta, envia para a nuvem.
/// Sem internet o app continua funcionando e envia depois.
class FinanceStore extends ChangeNotifier {
  FinanceStore(
    this.preferences,
    this.data, {
    this.remote,
    this.storageKey = legacyKey,
  });
  final SharedPreferencesAsync preferences;
  final FinanceRemote? remote;
  final String storageKey;
  FinanceData data;

  /// Há alterações gravadas no aparelho que ainda não chegaram à nuvem.
  bool pendingSync = false;

  /// Chave usada antes das contas de usuário existirem.
  static const legacyKey = 'agricultura_financas_v1';
  static String keyFor(String? userId) =>
      userId == null ? legacyKey : '${legacyKey}_$userId';
  static String _recoveryKey(String key) => '${key}_recuperacao';
  static String _pendingKey(String key) => '${key}_pendente';
  Future<void> _pending = Future.value();

  static Future<FinanceStore> open({
    FinanceRemote? remote,
    String? userId,
  }) async {
    final preferences = SharedPreferencesAsync();
    final key = keyFor(userId);
    var raw = await preferences.getString(key);
    var pending = await preferences.getBool(_pendingKey(key)) ?? false;
    var migrated = false;
    if (remote != null && !pending) {
      try {
        final cloud = await remote.load();
        if (cloud != null) {
          raw = cloud;
          await preferences.setString(key, cloud);
        } else if (raw == null && key != legacyKey) {
          // Primeiro acesso: leva para a conta o que já estava no aparelho.
          raw = await preferences.getString(legacyKey);
          migrated = raw != null;
        }
        pending = cloud == null && raw != null;
      } catch (_) {
        // Sem internet: segue com a cópia do aparelho.
      }
    }
    final store = FinanceStore(
      preferences,
      raw == null ? FinanceData() : FinanceData.decode(raw),
      remote: remote,
      storageKey: key,
    )..pendingSync = pending;
    if (migrated) {
      await preferences.setString(key, raw!);
      await preferences.remove(legacyKey);
    }
    if (pending) store.save().catchError((Object _) {});
    return store;
  }

  /// Conteúdo gravado sem interpretar, para recuperar dados que não abrem.
  static Future<String?> readRaw({String? userId}) =>
      SharedPreferencesAsync().getString(keyFor(userId));

  /// Guarda uma cópia dos dados ilegíveis e começa vazio.
  static Future<FinanceStore> startOver({
    FinanceRemote? remote,
    String? userId,
  }) async {
    final preferences = SharedPreferencesAsync();
    final key = keyFor(userId);
    final raw = await preferences.getString(key);
    if (raw != null) await preferences.setString(_recoveryKey(key), raw);
    await preferences.remove(key);
    await preferences.remove(_pendingKey(key));
    return FinanceStore(
      preferences,
      FinanceData(),
      remote: remote,
      storageKey: key,
    );
  }

  /// Grava no aparelho e tenta enviar para a nuvem. Só lança erro se a
  /// gravação no aparelho falhar; falha de envio fica em [pendingSync].
  Future<void> save() {
    final snapshot = data.encode();
    notifyListeners();
    final write = _pending.then((_) async {
      await preferences.setString(storageKey, snapshot);
      final remote = this.remote;
      if (remote == null) return;
      await preferences.setBool(_pendingKey(storageKey), true);
      try {
        await remote.save(snapshot);
        await preferences.setBool(_pendingKey(storageKey), false);
        _setPending(false);
      } catch (_) {
        _setPending(true);
      }
    });
    _pending = write.catchError((Object _) {});
    return write;
  }

  void _setPending(bool value) {
    if (pendingSync == value) return;
    pendingSync = value;
    notifyListeners();
  }
}
