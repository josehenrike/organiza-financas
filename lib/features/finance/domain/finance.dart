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

int? parseMoney(String text) {
  var v = text.replaceAll('R\$', '').replaceAll(RegExp(r'\s'), '');
  if (v.contains(',')) v = v.replaceAll('.', '').replaceAll(',', '.');
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
    this.withdrawal = 0,
    this.withdrawalDay = 5,
    this.reserveAllocation = 0,
  }) : items = items ?? [],
       spending = spending ?? [],
       paid = paid ?? {};
  final String key;
  final List<PlanItem> items;
  final List<Spending> spending;
  final Set<String> paid;
  int withdrawal, withdrawalDay, reserveAllocation;
  DateTime get date => DateTime.parse('$key-01');
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
    for (final p in Pocket.values) {
      if (withdrawal > 0) {
        result.add(
          AgendaEntry(
            'withdrawal',
            'Retirada para a família',
            p,
            p == Pocket.family,
            withdrawal,
            min(withdrawalDay, last),
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

  bool isPaid(AgendaEntry e) =>
      e.id.startsWith('spend:') || paid.contains(e.id);
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
    final next = MonthPlan(
      key: nextKey,
      withdrawal: withdrawal,
      withdrawalDay: withdrawalDay,
      reserveAllocation: reserveAllocation,
    );
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
    'withdrawal': withdrawal,
    'withdrawalDay': withdrawalDay,
    'reserveAllocation': reserveAllocation,
  };
  factory MonthPlan.fromJson(Map<String, dynamic> j) => MonthPlan(
    key: j['key'],
    items: (j['items'] as List).map((i) => PlanItem.fromJson(i)).toList(),
    spending: (j['spending'] as List).map((s) => Spending.fromJson(s)).toList(),
    paid: Set<String>.from(j['paid']),
    withdrawal: j['withdrawal'],
    withdrawalDay: j['withdrawalDay'],
    reserveAllocation: j['reserveAllocation'],
  );
}

class FinanceData {
  FinanceData({
    Map<String, MonthPlan>? months,
    this.reserveGoal = 0,
    this.reserveSaved = 0,
    this.reserveMonthly = 0,
    this.demo = false,
  }) : months = months ?? {};
  final Map<String, MonthPlan> months;
  int reserveGoal, reserveSaved, reserveMonthly;
  bool demo;
  MonthPlan month(String key) => months.putIfAbsent(key, () {
    final previous = months.keys.where((k) => k.compareTo(key) < 0).toList()
      ..sort();
    return previous.isEmpty
        ? MonthPlan(key: key)
        : months[previous.last]!.repeat(key);
  });
  String encode() => jsonEncode({
    'version': 1,
    'demo': demo,
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
      demo: j['demo'],
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
      require(
        m.withdrawal >= 0 &&
            m.withdrawalDay >= 1 &&
            m.withdrawalDay <= 31 &&
            m.reserveAllocation >= 0,
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
    final match = RegExp(r'\d+(?:[.,]\d{1,2})?').firstMatch(text);
    final amount = match == null ? null : parseMoney(match.group(0)!);
    var description = text.replaceFirst(
      RegExp(r'^\s*(gastei|comprei|paguei)\s*', caseSensitive: false),
      '',
    );
    if (match != null) {
      description = description.replaceFirst(match.group(0)!, '');
    }
    description = description
        .replaceFirst(
          RegExp(r'^\s*(reais\s*)?(na|no|em|de)?\s*', caseSensitive: false),
          '',
        )
        .trim();
    return VoiceDraft(description, amount);
  }
}
