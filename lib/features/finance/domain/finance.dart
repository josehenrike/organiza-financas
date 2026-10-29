import 'dart:convert';
import 'dart:math';

enum Pocket { business, family }

enum Group { income, fixed, installment, variable, occasional }

String pocketName(Pocket p) => p == Pocket.business ? 'Negócio' : 'Família';
String groupName(Group g) => const [
  'Entradas',
  'Fixos',
  'Parcelados',
  'Variáveis com limite',
  'Eventuais',
][g.index];
String newId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1000000)}';
String monthKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';

/// Descreve dias do mês em português: "dia 5", "dias 10 e 25".
String daysLabel(List<int> days) {
  if (days.length == 1) return 'dia ${days.first}';
  final head = days.take(days.length - 1).join(', ');
  return 'dias $head e ${days.last}';
}

int? parseMoney(String text) {
  var v = text.replaceAll('R\$', '').replaceAll(RegExp(r'\s'), '');
  if (v.contains(',')) {
    v = v.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(v)) {
    // "1.250" sem vírgula é milhar, não decimal.
    v = v.replaceAll('.', '');
  }
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(v)) return null;
  final n = double.tryParse(v);
  if (n == null || !n.isFinite || n > 999999999) return null;
  return (n * 100).round();
}

class PlanItem {
  PlanItem({
    required this.id,
    required this.pocket,
    required this.group,
    required this.name,
    required this.amount,
    this.days = const [5],
    this.part = 1,
    this.parts = 1,
    this.track = false,
  });
  final String id;
  final Pocket pocket;
  final Group group;
  final String name;
  final int amount;
  final List<int> days;
  final int part;
  final int parts;
  bool track;
  Map<String, dynamic> toJson() => {
    'id': id,
    'pocket': pocket.name,
    'group': group.name,
    'name': name,
    'amount': amount,
    'days': days,
    'part': part,
    'parts': parts,
    'track': track,
  };
  factory PlanItem.fromJson(Map<String, dynamic> j) => PlanItem(
    id: j['id'],
    pocket: Pocket.values.byName(j['pocket']),
    group: Group.values.byName(j['group']),
    name: j['name'],
    amount: j['amount'],
    days: List<int>.from(j['days']),
    part: j['part'],
    parts: j['parts'],
    track: j['track'],
  );
}

class Spending {
  Spending({
    required this.id,
    required this.itemId,
    required this.description,
    required this.amount,
    required this.date,
    this.voice = false,
  });
  final String id, itemId, description;
  final int amount;
  final DateTime date;
  final bool voice;
  Map<String, dynamic> toJson() => {
    'id': id,
    'itemId': itemId,
    'description': description,
    'amount': amount,
    'date': date.toIso8601String(),
    'voice': voice,
  };
  factory Spending.fromJson(Map<String, dynamic> j) => Spending(
    id: j['id'],
    itemId: j['itemId'],
    description: j['description'],
    amount: j['amount'],
    date: DateTime.parse(j['date']),
    voice: j['voice'],
  );
}

/// Dinheiro que sai do negócio para a casa. Pode acontecer várias vezes no
/// mês, em valores pequenos, e não se repete nos meses seguintes.
class Withdrawal {
  Withdrawal({required this.id, required this.amount, required this.day});
  final String id;
  final int amount, day;
  Map<String, dynamic> toJson() => {'id': id, 'amount': amount, 'day': day};
  factory Withdrawal.fromJson(Map<String, dynamic> j) =>
      Withdrawal(id: j['id'], amount: j['amount'], day: j['day']);
}

class AgendaEntry {
  AgendaEntry(
    this.id,
    this.name,
    this.pocket,
    this.income,
    this.amount,
    this.day, {
    this.transfer = false,
  });
  final String id, name;
  final Pocket pocket;
  final bool income, transfer;
  final int amount, day;
}

class MonthPlan {
  MonthPlan({
    required this.key,
    List<PlanItem>? items,
    List<Spending>? spending,
    Set<String>? paid,
    List<Withdrawal>? withdrawals,
    this.reserveAllocation = 0,
    this.reserveDeposited = false,
  }) : items = items ?? [],
       spending = spending ?? [],
       paid = paid ?? {},
       withdrawals = withdrawals ?? [];
  final String key;
  final List<PlanItem> items;
  final List<Spending> spending;
  final Set<String> paid;
  final List<Withdrawal> withdrawals;
  int reserveAllocation;
  bool reserveDeposited;
  DateTime get date => DateTime.parse('$key-01');

  /// Soma das retiradas registradas no mês.
  int get withdrawal => withdrawals.fold(0, (v, w) => v + w.amount);
  int spent(String id) =>
      spending.where((s) => s.itemId == id).fold(0, (v, s) => v + s.amount);
  List<AgendaEntry> get agenda {
    final result = <AgendaEntry>[];
    final last = DateTime(date.year, date.month + 1, 0).day;
    for (final item in items.where((i) => i.group != Group.variable)) {
      for (var n = 0; n < item.days.length; n++) {
        result.add(
          AgendaEntry(
            '${item.id}:$n',
            item.name,
            item.pocket,
            item.group == Group.income,
            item.amount ~/ item.days.length +
                (n == 0 ? item.amount % item.days.length : 0),
            min(item.days[n], last),
          ),
        );
      }
    }
    for (final w in withdrawals) {
      for (final p in Pocket.values) {
        result.add(
          AgendaEntry(
            'withdrawal:${w.id}',
            'Retirada para a família',
            p,
            p == Pocket.family,
            w.amount,
            min(w.day, last),
            transfer: true,
          ),
        );
      }
    }
    for (final s in spending) {
      final item = items.where((i) => i.id == s.itemId).firstOrNull;
      if (item != null) {
        result.add(
          AgendaEntry(
            'spend:${s.id}',
            s.description,
            item.pocket,
            false,
            s.amount,
            s.date.day,
          ),
        );
      }
    }
    result.sort((a, b) => a.day.compareTo(b.day));
    return result;
  }

  /// Gastos e retiradas são registrados quando acontecem, então já contam
  /// como pagos.
  static bool isRegistered(AgendaEntry e) =>
      e.id.startsWith('spend:') || e.id.startsWith('withdrawal:');
  bool isPaid(AgendaEntry e) => isRegistered(e) || paid.contains(e.id);
  int income(Pocket p, {bool actual = false}) => agenda
      .where((e) => e.pocket == p && e.income && (!actual || isPaid(e)))
      .fold(0, (v, e) => v + e.amount);
  int costs(Pocket p, {bool actual = false}) => agenda
      .where(
        (e) =>
            e.pocket == p && !e.income && !e.transfer && (!actual || isPaid(e)),
      )
      .fold(0, (v, e) => v + e.amount);
  int balance(Pocket p, {bool actual = false}) =>
      income(p, actual: actual) - costs(p, actual: actual);
  int groupTotal(Pocket p, Group g) =>
      items
          .where((i) => i.pocket == p && i.group == g)
          .fold(
            0,
            (v, i) => v + (g == Group.variable ? spent(i.id) : i.amount),
          ) +
      (p == Pocket.family && g == Group.income ? withdrawal : 0);
  MonthPlan repeat(String nextKey) {
    final next = MonthPlan(key: nextKey, reserveAllocation: reserveAllocation);
    final nextDate = next.date;
    final elapsed =
        (nextDate.year - date.year) * 12 + nextDate.month - date.month;
    for (final item in items) {
      if (item.group == Group.occasional) continue;
      if (item.group == Group.installment && item.part + elapsed > item.parts) {
        continue;
      }
      final data = item.toJson();
      if (item.group == Group.installment) data['part'] = item.part + elapsed;
      next.items.add(PlanItem.fromJson(data));
    }
    return next;
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'items': items.map((i) => i.toJson()).toList(),
    'spending': spending.map((s) => s.toJson()).toList(),
    'paid': paid.toList(),
    'withdrawals': withdrawals.map((w) => w.toJson()).toList(),
    'reserveAllocation': reserveAllocation,
    'reserveDeposited': reserveDeposited,
  };
  factory MonthPlan.fromJson(Map<String, dynamic> j) {
    final paid = Set<String>.from(j['paid']);
    final withdrawals = j['withdrawals'] == null
        ? <Withdrawal>[]
        : (j['withdrawals'] as List)
              .map((w) => Withdrawal.fromJson(w))
              .toList();
    // Backups antigos tinham uma única retirada mensal fixa.
    if (j['withdrawals'] == null && (j['withdrawal'] ?? 0) != 0) {
      withdrawals.add(
        Withdrawal(
          id: 'mensal',
          amount: j['withdrawal'],
          day: j['withdrawalDay'] ?? 5,
        ),
      );
    }
    paid.remove('withdrawal');
    return MonthPlan(
      key: j['key'],
      items: (j['items'] as List).map((i) => PlanItem.fromJson(i)).toList(),
      spending: (j['spending'] as List)
          .map((s) => Spending.fromJson(s))
          .toList(),
      paid: paid,
      withdrawals: withdrawals,
      reserveAllocation: j['reserveAllocation'],
      reserveDeposited: j['reserveDeposited'] ?? false,
    );
  }
}

class FinanceData {
  FinanceData({
    Map<String, MonthPlan>? months,
    this.reserveGoal = 0,
    this.reserveSaved = 0,
    this.reserveMonthly = 0,
  }) : months = months ?? {};
  final Map<String, MonthPlan> months;
  int reserveGoal, reserveSaved, reserveMonthly;

  /// Mês salvo ou, se ainda não existe, cria e guarda a partir do anterior.
  MonthPlan month(String key) => months.putIfAbsent(key, () => preview(key));

  /// Mês salvo ou um rascunho não gravado, repetido do mês anterior mais
  /// próximo. Permite navegar sem criar meses.
  MonthPlan preview(String key) {
    final saved = months[key];
    if (saved != null) return saved;
    final previous = months.keys.where((k) => k.compareTo(key) < 0).toList()
      ..sort();
    return previous.isEmpty
        ? MonthPlan(key: key)
        : months[previous.last]!.repeat(key);
  }

  /// Mês anterior mais próximo que já existe, de onde um rascunho é copiado.
  String? sourceOf(String key) {
    if (months.containsKey(key)) return null;
    final previous = months.keys.where((k) => k.compareTo(key) < 0).toList()
      ..sort();
    return previous.lastOrNull;
  }

  String encode() => jsonEncode({
    'version': 1,
    'reserveGoal': reserveGoal,
    'reserveSaved': reserveSaved,
    'reserveMonthly': reserveMonthly,
    'months': months.map((k, m) => MapEntry(k, m.toJson())),
  });
  factory FinanceData.decode(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    if (j['version'] != 1) {
      throw const FormatException('Versão de arquivo desconhecida');
    }
    final data = FinanceData(
      months: (j['months'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, MonthPlan.fromJson(v)),
      ),
      reserveGoal: j['reserveGoal'],
      reserveSaved: j['reserveSaved'],
      reserveMonthly: j['reserveMonthly'],
    );
    void require(bool condition) {
      if (!condition) throw const FormatException('Dados inválidos no backup');
    }

    require(
      data.reserveGoal >= 0 &&
          data.reserveSaved >= 0 &&
          data.reserveMonthly >= 0,
    );
    for (final entry in data.months.entries) {
      final m = entry.value;
      require(
        RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(entry.key) &&
            m.key == entry.key,
      );
      require(m.reserveAllocation >= 0);
      require(
        m.withdrawals.every((w) => w.amount > 0 && w.day >= 1 && w.day <= 31),
      );
      require(
        m.withdrawals.map((w) => w.id).toSet().length == m.withdrawals.length,
      );
      require(m.items.map((i) => i.id).toSet().length == m.items.length);
      require(m.spending.map((s) => s.id).toSet().length == m.spending.length);
      for (final item in m.items) {
        require(
          item.id.isNotEmpty && item.name.trim().isNotEmpty && item.amount > 0,
        );
        require(
          item.days.isNotEmpty &&
              item.days.every((d) => d >= 1 && d <= 31) &&
              item.days.toSet().length == item.days.length,
        );
        require(item.part >= 1 && item.parts >= item.part);
      }
      for (final s in m.spending) {
        require(
          s.amount > 0 &&
              s.description.trim().isNotEmpty &&
              monthKey(s.date) == m.key,
        );
        require(
          m.items.any((i) => i.id == s.itemId && i.group == Group.variable),
        );
      }
      require(m.paid.every((id) => m.agenda.any((e) => e.id == id)));
    }
    return data;
  }
}

class VoiceDraft {
  VoiceDraft(this.description, this.amount);
  final String description;
  final int? amount;
  factory VoiceDraft.parse(String text) {
    final match = RegExp(
      r'\d{1,3}(?:\.\d{3})+(?:,\d{1,2})?|\d+(?:[.,]\d{1,2})?',
    ).firstMatch(text);
    final amount = match == null ? null : parseMoney(match.group(0)!);
    var description = text.replaceAll(RegExp(r'R\$\s*'), '');
    if (match != null) {
      description = description.replaceFirst(match.group(0)!, ' ');
    }
    description = description
        .replaceFirst(
          RegExp(r'^\s*(eu\s+)?(gastei|comprei|paguei)', caseSensitive: false),
          '',
        )
        .replaceFirst(
          RegExp(
            r'^\s*((reais|real)(\s+|$))?(e\s+\d+\s+centavos(\s+|$))?'
            r'((na|no|nas|nos|em|de|da|do|com)\s+)?',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (description.isNotEmpty) {
      description = description[0].toUpperCase() + description.substring(1);
    }
    return VoiceDraft(description, amount);
  }
}
