import '../domain/finance.dart';

FinanceData demoData() {
  final d = FinanceData(
    demo: true,
    reserveGoal: 100000,
    reserveSaved: 65000,
    reserveMonthly: 20000,
  );
  final m = MonthPlan(
    key: '2026-10',
    withdrawal: 250000,
    reserveAllocation: 20000,
  );
  d.months[m.key] = m;
  void add(
    String id,
    Pocket p,
    Group g,
    String name,
    int reais,
    List<int> days, {
    int part = 1,
    int parts = 1,
    bool track = false,
  }) {
    m.items.add(
      PlanItem(
        id: id,
        pocket: p,
        group: g,
        name: name,
        amount: reais * 100,
        days: days,
        part: part,
        parts: parts,
        track: track,
      ),
    );
  }

  const b = Pocket.business, f = Pocket.family;
  add('leite', b, Group.income, 'Venda de leite', 4800, [10, 25]);
  add('horta', b, Group.income, 'Feira da horta', 2600, [3, 10, 17, 24, 31]);
  add('ovos', b, Group.income, 'Ovos', 1000, [3, 10, 17, 24, 31]);
  add('diarias', f, Group.income, 'Diárias fora', 400, [20]);
  add('diarista', b, Group.fixed, 'Diarista fixo', 900, [5]);
  add('curral', b, Group.fixed, 'Energia do curral', 250, [10]);
  add(
    'pronaf',
    b,
    Group.installment,
    'Pronaf: ordenhadeira',
    500,
    [15],
    part: 3,
    parts: 10,
  );
  add('insumos', b, Group.variable, 'Insumos do leite', 2000, [1], track: true);
  add('adubo', b, Group.variable, 'Adubo e sementes', 800, [1]);
  add('combustivel', b, Group.variable, 'Combustível', 400, [1]);
  add('cerca', b, Group.occasional, 'Conserto da cerca', 300, [7]);
  add('frete', b, Group.occasional, 'Frete', 180, [11]);
  add('escola', f, Group.fixed, 'Transporte escolar', 150, [5]);
  add('energia', f, Group.fixed, 'Energia e água', 280, [10]);
  add('internet', f, Group.fixed, 'Celular e internet', 120, [12]);
  add('moto', f, Group.installment, 'Moto', 420, [20], part: 5, parts: 12);
  add(
    'geladeira',
    f,
    Group.installment,
    'Geladeira',
    180,
    [25],
    part: 2,
    parts: 10,
  );
  add('alimentacao', f, Group.variable, 'Alimentação', 1000, [1], track: true);
  add('gas', f, Group.variable, 'Gás de cozinha', 130, [1]);
  add('farmacia', f, Group.variable, 'Farmácia', 150, [1]);
  add('lazer', f, Group.variable, 'Lazer', 150, [1]);
  add('presente', f, Group.occasional, 'Presente de aniversário', 60, [22]);
  void spend(String item, String name, int reais, int day) => m.spending.add(
    Spending(
      id: newId(),
      itemId: item,
      description: name,
      amount: reais * 100,
      date: DateTime(2026, 10, day),
    ),
  );
  spend('alimentacao', 'Mercado', 280, 2);
  spend('alimentacao', 'Açougue', 120, 9);
  spend('alimentacao', 'Mercado', 190, 15);
  spend('alimentacao', 'Padaria', 50, 17);
  spend('insumos', 'Ração (18 sacos)', 900, 3);
  spend('insumos', 'Remédio e vacina', 280, 8);
  spend('insumos', 'Sal mineral', 170, 12);
  spend('insumos', 'Ração (10 sacos)', 500, 16);
  spend('adubo', 'Adubo e sementes', 750, 8);
  spend('combustivel', 'Combustível', 370, 10);
  spend('gas', 'Botijão de gás', 130, 8);
  spend('farmacia', 'Medicamentos', 120, 9);
  spend('lazer', 'Passeio da família', 80, 12);
  m.paid.addAll(
    m.agenda
        .where((e) => e.day <= 18 && !e.id.startsWith('spend:'))
        .map((e) => e.id),
  );
  return d;
}
