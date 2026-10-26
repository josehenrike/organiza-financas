import 'package:flutter_test/flutter_test.dart';
import 'package:organiza_financas/features/finance/data/demo_data.dart';
import 'package:organiza_financas/features/finance/domain/finance.dart';

void main() {
  test('valores do PDF fecham sem duplicar a retirada', () {
    final m = demoData().month('2026-10');
    expect(m.income(Pocket.business), 840000);
    expect(m.costs(Pocket.business), 510000);
    expect(m.balance(Pocket.business), 330000);
    expect(m.income(Pocket.family), 290000);
    expect(m.costs(Pocket.family), 218000);
    expect(m.balance(Pocket.family), 72000);
    expect(
      m.balance(Pocket.business) - m.withdrawal - m.reserveAllocation,
      60000,
    );
    expect(m.spent('alimentacao'), 64000);
    expect(m.spent('insumos'), 185000);
  });
  test('retirada tem uma única confirmação nos dois bolsos', () {
    final m = MonthPlan(key: '2026-10', withdrawal: 250000);
    expect(m.income(Pocket.family, actual: true), 0);
    m.paid.add('withdrawal');
    expect(m.income(Pocket.family, actual: true), 250000);
    expect(m.agenda.where((e) => e.transfer).every(m.isPaid), isTrue);
    expect(m.costs(Pocket.business, actual: true), 0);
  });
  test(
    'repetição avança parcelas e não copia eventuais, pagamentos ou gastos',
    () {
      final m = demoData().month('2026-10');
      final next = m.repeat('2026-11');
      expect(next.items.firstWhere((i) => i.id == 'pronaf').part, 4);
      expect(next.items.where((i) => i.group == Group.occasional), isEmpty);
      expect(next.spending, isEmpty);
      expect(next.paid, isEmpty);
      expect(next.withdrawal, m.withdrawal);
      expect(m.repeat('2027-07').items.where((i) => i.id == 'pronaf'), isEmpty);
      expect(m.spending, isNotEmpty);
    },
  );
  test('agenda divide centavos sem perda e ajusta dia 31 em fevereiro', () {
    final m = MonthPlan(
      key: '2027-02',
      items: [
        PlanItem(
          id: 'a',
          pocket: Pocket.business,
          group: Group.income,
          name: 'Leite',
          amount: 10001,
          days: [10, 31],
        ),
      ],
    );
    expect(m.agenda.map((e) => e.day), [10, 28]);
    expect(m.income(Pocket.business), 10001);
    m.paid.add('a:0');
    expect(m.income(Pocket.business, actual: true), 5001);
  });
  test('saldo variável pode ficar negativo, sem ocultar excesso', () {
    final m = demoData().month('2026-10');
    m.spending.add(
      Spending(
        id: 'extra',
        itemId: 'alimentacao',
        description: 'Mercado',
        amount: 40000,
        date: DateTime(2026, 10, 20),
      ),
    );
    expect(100000 - m.spent('alimentacao'), -4000);
    expect(m.costs(Pocket.family), 258000);
  });
  test('backup mantém meses, parcelas, pagamentos e gastos', () {
    final d = demoData();
    d.month('2026-11');
    final restored = FinanceData.decode(d.encode());
    expect(restored.encode(), d.encode());
    expect(() => FinanceData.decode('{"version":2}'), throwsFormatException);
  });
  test('valores brasileiros e rascunho por voz', () {
    expect(parseMoney('R\$ 1.250,90'), 125090);
    expect(parseMoney('50'), 5000);
    expect(parseMoney('-1'), isNull);
    expect(parseMoney('abc'), isNull);
    final draft = VoiceDraft.parse('gastei 50 na padaria');
    expect(draft.amount, 5000);
    expect(draft.description, 'padaria');
    expect(VoiceDraft.parse('comprei 120 de remédio').description, 'remédio');
  });
}
