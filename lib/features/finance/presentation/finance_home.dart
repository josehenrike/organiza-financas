import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../data/demo_data.dart';
import '../data/finance_store.dart';
import '../domain/finance.dart';
import 'finance_widgets.dart';
import 'item_form.dart';
import 'limit_page.dart';

class FinanceHome extends StatefulWidget {
  const FinanceHome({super.key, required this.store});
  final FinanceStore store;
  @override
  State<FinanceHome> createState() => _FinanceHomeState();
}

class _FinanceHomeState extends State<FinanceHome> {
  int tab = 0;
  late DateTime selected = DateTime(DateTime.now().year, DateTime.now().month);
  Pocket? agendaPocket;
  bool actual = false;
  FinanceData get data => widget.store.data;
  MonthPlan get month => data.month(monthKey(selected));
  String? saveError;
  final scroll = ScrollController();
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() {});
    try {
      await widget.store.save();
      if (mounted) setState(() => saveError = null);
    } catch (_) {
      if (mounted) {
        setState(
          () => saveError =
              'Não foi possível salvar no dispositivo. Mantenha o app aberto e tente novamente.',
        );
      }
    }
  }

  void go(int index) {
    setState(() => tab = index);
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  Future<void> edit(Pocket p, Group g, [PlanItem? old]) async {
    final item = await showDialog<PlanItem>(
      context: context,
      builder: (_) => ItemForm(pocket: p, group: g, item: old),
    );
    if (item == null) return;
    if (old != null) {
      if ((item.amount != old.amount ||
              item.days.join(',') != old.days.join(',')) &&
          month.agenda.any(
            (e) => e.id.startsWith('${old.id}:') && month.isPaid(e),
          )) {
        if (!mounted ||
            !await confirm(
              context,
              'Atualizar agenda?',
              'Alterar o valor ou os dias desmarca os pagamentos deste item para você conferir novamente.',
            )) {
          return;
        }
        month.paid.removeWhere((id) => id.startsWith('${old.id}:'));
      }
      month.items[month.items.indexOf(old)] = item;
    } else {
      month.items.add(item);
    }
    await save();
  }

  Future<void> openLimit(PlanItem item) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => LimitPage(item: item, month: month, onSave: save),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final color = tab == 2 ? familyColor : businessColor;
    final content = switch (tab) {
      0 => registration(),
      1 => planning(Pocket.business),
      2 => planning(Pocket.family),
      3 => agenda(),
      _ => results(),
    };
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.spa_outlined, color: color),
            const SizedBox(width: 10),
            const Flexible(child: Text('Organiza Finanças')),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Opções e cópia de segurança',
            onSelected: options,
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'backup',
                child: Text('Copiar backup'),
              ),
              const PopupMenuItem(
                value: 'restore',
                child: Text('Restaurar backup'),
              ),
              if (data.months.values.every(
                    (m) => m.items.isEmpty && m.withdrawal == 0,
                  ) &&
                  data.reserveSaved == 0)
                const PopupMenuItem(
                  value: 'demo',
                  child: Text('Explorar exemplo do PDF'),
                ),
              if (data.demo)
                const PopupMenuItem(
                  value: 'clearDemo',
                  child: Text('Sair da demonstração'),
                ),
            ],
          ),
        ],
      ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              selectedIndex: tab,
              onDestinationSelected: go,
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.all(20),
                child: Icon(
                  Icons.agriculture_outlined,
                  size: 36,
                  color: businessColor,
                ),
              ),
              destinations: destinations
                  .map(
                    (d) => NavigationRailDestination(
                      icon: Icon(d.$2),
                      label: Text(d.$1),
                    ),
                  )
                  .toList(),
            ),
          Expanded(
            child: Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Mês anterior',
                        onPressed: () => changeMonth(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Flexible(
                        child: Text(
                          monthTitle(selected),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Próximo mês',
                        onPressed: () => changeMonth(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
                if (data.demo)
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFFFECCD),
                    padding: const EdgeInsets.all(8),
                    child: const Text(
                      'DEMONSTRAÇÃO • Valores fictícios do PDF',
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (saveError != null)
                  MaterialBanner(
                    content: Text(saveError!),
                    actions: [
                      TextButton(
                        onPressed: save,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: ListView(
                        controller: scroll,
                        padding: EdgeInsets.all(wide ? 32 : 16),
                        children: [
                          ...content,
                          const SizedBox(height: 24),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.phone_android,
                                size: 16,
                                color: Colors.black54,
                              ),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Dados neste dispositivo • Sem sincronização em nuvem',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: go,
              destinations: destinations
                  .map(
                    (d) => NavigationDestination(icon: Icon(d.$2), label: d.$1),
                  )
                  .toList(),
            ),
    );
  }

  static const destinations = [
    ('Cadastro', Icons.edit_note),
    ('Negócio', Icons.agriculture_outlined),
    ('Família', Icons.home_outlined),
    ('Agenda', Icons.calendar_month_outlined),
    ('Resultado', Icons.bar_chart_outlined),
  ];
  void changeMonth(int delta) {
    setState(() => selected = DateTime(selected.year, selected.month + delta));
    data.month(monthKey(selected));
    save();
  }

  List<Widget> registration() => [
    const Heading(
      'Cada dinheiro no seu lugar',
      subtitle: 'Cuide da roça e da casa, um passo de cada vez.',
    ),
    Panel(
      color: const Color(0xFFEAF1E6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.eco_outlined, color: businessColor, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Comece pelas rendas do mês',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Depois, combine a retirada da família e planeje os gastos. Você pode ajustar tudo quando precisar.',
                ),
                if (data.months.values.every(
                  (m) => m.items.isEmpty && m.withdrawal == 0,
                ))
                  TextButton(
                    onPressed: () => options('demo'),
                    child: const Text('Conhecer o app com os exemplos do PDF'),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
    section(Pocket.business, Group.income),
    section(Pocket.family, Group.income),
    Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'A ponte entre a roça e a casa',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'A retirada sai do caixa do negócio e entra automaticamente como renda da família.',
          ),
          const SizedBox(height: 16),
          Text(
            money(month.withdrawal),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          Text('Todo dia ${month.withdrawalDay}'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: editWithdrawal,
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Combinar retirada'),
          ),
        ],
      ),
    ),
    reservePanel(),
    FilledButton.icon(
      onPressed: () => go(1),
      icon: const Icon(Icons.arrow_forward),
      label: const Text('Continuar: planejar o negócio'),
    ),
  ];

  List<Widget> planning(Pocket p) {
    final tracked = month.items
        .where((i) => i.pocket == p && i.group == Group.variable && i.track)
        .toList();
    return [
      Heading(
        p == Pocket.business ? 'O negócio da família' : 'A família e a casa',
        subtitle:
            'Planejamento do mês • valores previstos e gastos variáveis registrados',
      ),
      Summary(
        income: month.income(p),
        costs: month.costs(p),
        color: pocketColor(p),
      ),
      if (p == Pocket.business && month.withdrawal > 0)
        Panel(
          child: Text(
            'Depois da retirada (${money(month.withdrawal)}) e da reserva planejada (${money(month.reserveAllocation)}), ficam ${money(month.balance(p) - month.withdrawal - month.reserveAllocation)} no caixa.',
          ),
        ),
      if (tracked.isNotEmpty) ...[
        const Heading(
          'De olho nos limites',
          subtitle: 'Toque em uma categoria para registrar um gasto.',
        ),
        for (final item in tracked) limitCard(item),
      ],
      section(p, Group.income),
      const Heading('Gastos que não mudam'),
      section(p, Group.fixed),
      section(p, Group.installment),
      const Heading('Gastos que mudam'),
      section(p, Group.variable),
      section(p, Group.occasional),
      FilledButton.icon(
        onPressed: () => go(3),
        icon: const Icon(Icons.calendar_month),
        label: const Text('Ver agenda da semana'),
      ),
    ];
  }

  Widget limitCard(PlanItem item) {
    final spent = month.spent(item.id),
        ratio = month.spent(item.id) / max(1, item.amount);
    return Panel(
      child: InkWell(
        onTap: () => openLimit(item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward, size: 22),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${money(item.amount - spent)} disponíveis',
                style: TextStyle(
                  color: ratio >= .8 ? fixedColor : pocketColor(item.pocket),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: ratio.clamp(0, 1),
                color: ratio >= .8 ? fixedColor : pocketColor(item.pocket),
                backgroundColor: const Color(0xFFE9EDE6),
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 8),
              Text(
                'Gastou ${money(spent)} de ${money(item.amount)}${ratio >= .8 ? ' · Atenção ao limite' : ''}',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget section(Pocket p, Group g) {
    final items = month.items
        .where((i) => i.pocket == p && i.group == g)
        .toList();
    final color = g == Group.income
        ? pocketColor(p)
        : (g == Group.fixed || g == Group.installment
              ? fixedColor
              : variableColor);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 16,
            runSpacing: 8,
            children: [
              Text(
                '${groupName(g)}${tab == 0 ? ' · ${pocketName(p)}' : ''}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                money(month.groupTotal(p, g)),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          if (g == Group.variable)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Total gasto • Marque as categorias que quer acompanhar.',
              ),
            ),
          const SizedBox(height: 12),
          if (p == Pocket.family && g == Group.income)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.swap_horiz, color: familyColor),
              title: const Text('Retirada do negócio'),
              subtitle: Text(
                'Dia ${month.withdrawalDay} · ${money(month.withdrawal)}',
              ),
              onTap: editWithdrawal,
              trailing: const Icon(Icons.edit_outlined),
            ),
          if (items.isEmpty && !(p == Pocket.family && g == Group.income))
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Nenhum item cadastrado. Comece pelo botão abaixo.'),
            ),
          for (final item in items) ...[
            const Divider(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (g == Group.variable)
                  Checkbox(
                    value: item.track,
                    onChanged: (v) {
                      item.track = v!;
                      save();
                    },
                    semanticLabel: 'Acompanhar ${item.name}',
                  ),
                Expanded(
                  child: InkWell(
                    onTap: () => g == Group.variable
                        ? openLimit(item)
                        : edit(p, g, item),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            g == Group.variable
                                ? 'Limite ${money(item.amount)} · Gasto ${money(month.spent(item.id))}'
                                : '${money(item.amount)} · dia(s) ${item.days.join(', ')}${g == Group.installment ? ' · parcela ${item.part}/${item.parts}' : ''}',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Opções de ${item.name}',
                  onSelected: (v) async {
                    if (v == 'edit') {
                      await edit(p, g, item);
                      return;
                    }
                    if (!await confirm(
                      context,
                      'Excluir ${item.name}?',
                      'O planejamento e os lançamentos deste item neste mês serão excluídos.',
                    )) {
                      return;
                    }
                    month.items.remove(item);
                    month.spending.removeWhere((s) => s.itemId == item.id);
                    month.paid.removeWhere((s) => s.startsWith('${item.id}:'));
                    await save();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'delete', child: Text('Excluir')),
                  ],
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => edit(p, g),
            icon: const Icon(Icons.add),
            label: Text('Adicionar ${g == Group.income ? 'renda' : 'item'}'),
          ),
        ],
      ),
    );
  }

  Widget reservePanel() {
    final missing = max(0, data.reserveGoal - data.reserveSaved);
    final months = data.reserveMonthly > 0
        ? (missing / data.reserveMonthly).ceil()
        : null;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.savings_outlined, color: businessColor, size: 32),
          const SizedBox(height: 12),
          const Text(
            'Reserva do negócio',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text('Um dinheiro guardado para a roça não parar.'),
          const SizedBox(height: 20),
          Wrap(
            spacing: 28,
            runSpacing: 12,
            children: [
              Text('Meta\n${money(data.reserveGoal)}'),
              Text('Já guardei\n${money(data.reserveSaved)}'),
              Text('Falta\n${money(missing)}'),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: data.reserveGoal == 0
                ? 0
                : (data.reserveSaved / data.reserveGoal).clamp(0, 1),
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 12),
          Text(
            missing == 0 && data.reserveGoal > 0
                ? 'Meta alcançada!'
                : months == null
                ? 'Defina quanto pretende guardar por mês.'
                : 'Guardando ${money(data.reserveMonthly)} por mês, faltam $months aporte(s) para a meta.',
          ),
          const SizedBox(height: 12),
          Text(
            'Separar neste mês: ${money(month.reserveAllocation)}. O saldo guardado é atualizado por você ao fazer o depósito.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: editReserve,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Ajustar reserva'),
          ),
        ],
      ),
    );
  }

  List<Widget> agenda() {
    final entries = month.agenda
        .where((e) => agendaPocket == null || e.pocket == agendaPocket)
        .toList();
    final now = DateTime.now();
    return [
      const Heading(
        'O mês, semana a semana',
        subtitle:
            'Contas e recebimentos vêm do planejamento. Marque quando pagar ou receber.',
      ),
      Wrap(
        spacing: 8,
        children: [
          for (final p in <Pocket?>[null, ...Pocket.values])
            ChoiceChip(
              label: Text(p == null ? 'Tudo' : pocketName(p)),
              selected: agendaPocket == p,
              onSelected: (_) => setState(() => agendaPocket = p),
            ),
        ],
      ),
      const SizedBox(height: 20),
      for (var week = 0; week < 4; week++)
        Builder(
          builder: (context) {
            final start = week * 7 + 1,
                end = week == 3
                    ? DateTime(selected.year, selected.month + 1, 0).day
                    : week * 7 + 7;
            final rows = entries
                .where((e) => e.day >= start && e.day <= end)
                .toList();
            final totals = rows
                .where((e) => agendaPocket != null || !e.transfer)
                .toList();
            final income = totals
                .where((e) => e.income)
                .fold(0, (v, e) => v + e.amount);
            final costs = totals
                .where((e) => !e.income)
                .fold(0, (v, e) => v + e.amount);
            final current =
                monthKey(now) == month.key &&
                now.day >= start &&
                now.day <= end;
            return Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Semana ${week + 1} · dias $start a $end${current ? ' · esta semana' : ''}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (rows.isEmpty)
                    const Text('Nenhuma conta ou recebimento nesta semana.'),
                  for (final e in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F3ED),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${e.day}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${pocketName(e.pocket)}${e.transfer ? ' · transferência interna' : ''}',
                                  style: TextStyle(
                                    color: pocketColor(e.pocket),
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  '${e.income ? '+' : '−'} ${money(e.amount)}',
                                  style: TextStyle(
                                    color: e.income
                                        ? businessColor
                                        : fixedColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              Checkbox(
                                value: month.isPaid(e),
                                onChanged: e.id.startsWith('spend:')
                                    ? null
                                    : (v) {
                                        v!
                                            ? month.paid.add(e.id)
                                            : month.paid.remove(e.id);
                                        save();
                                      },
                                semanticLabel:
                                    '${e.income ? 'Recebido' : 'Pago'}: ${e.name}',
                              ),
                              Text(
                                month.isPaid(e)
                                    ? (e.income ? 'recebido' : 'pago')
                                    : 'pendente',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 28),
                  Wrap(
                    spacing: 24,
                    runSpacing: 8,
                    children: [
                      Text('Entra ${money(income)}'),
                      Text('Sai ${money(costs)}'),
                      Text(
                        '${income >= costs ? 'Sobra' : 'Falta'} ${money((income - costs).abs())}',
                        style: TextStyle(
                          color: income >= costs ? businessColor : fixedColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  if (costs > income)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Planeje guardar ${money(costs - income)} para cobrir esta semana.',
                        style: const TextStyle(color: fixedColor),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      if (agendaPocket == null)
        const Text(
          'Nos totais de “Tudo”, a retirada não é contada: ela apenas muda o dinheiro de bolso.',
        ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: addAgenda,
        icon: const Icon(Icons.add),
        label: const Text('Conta ou recebimento'),
      ),
    ];
  }

  List<Widget> results() {
    final b = month.balance(Pocket.business, actual: actual),
        f = month.balance(Pocket.family, actual: actual);
    final income = month.income(Pocket.business, actual: actual);
    final withdrawal = actual && !month.paid.contains('withdrawal')
        ? 0
        : month.withdrawal;
    final history =
        data.months.keys.where((k) => k.compareTo(month.key) <= 0).toList()
          ..sort();
    final recent = history.reversed.take(6).toList().reversed.toList();
    final maximum = max(
      1,
      recent.fold<int>(
        0,
        (v, k) => max(
          v,
          data.months[k]!.balance(Pocket.business, actual: actual).abs(),
        ),
      ),
    );
    return [
      const Heading(
        'Sobrou ou faltou?',
        subtitle: 'Entenda o resultado e escolha o próximo passo.',
      ),
      Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
            label: const Text('Planejamento'),
            selected: !actual,
            onSelected: (_) => setState(() => actual = false),
          ),
          ChoiceChip(
            label: const Text('Pago e recebido'),
            selected: actual,
            onSelected: (_) => setState(() => actual = true),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Text(
        actual
            ? 'Somente contas e rendas marcadas na agenda, mais os gastos variáveis registrados.'
            : 'Valores previstos do planejamento, mais os gastos variáveis já registrados. Não é uma projeção dos limites inteiros.',
      ),
      const SizedBox(height: 20),
      const Heading('Negócio'),
      Summary(
        income: income,
        costs: month.costs(Pocket.business, actual: actual),
        color: businessColor,
      ),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              income == 0
                  ? 'Sem entradas para calcular a lucratividade.'
                  : 'Lucratividade de ${(b / income * 100).round()}%: de cada R\$ 100 de entradas, ${b >= 0 ? 'sobraram' : 'faltaram'} ${money((b / income * 10000).abs().round())}.',
            ),
            const Divider(height: 32),
            const Text(
              'Para onde vai o resultado',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            resultLine('Retirada para a família', withdrawal),
            resultLine('Reserva planejada do mês', month.reserveAllocation),
            resultLine(
              'Caixa após retirada e reserva planejada',
              b - withdrawal - month.reserveAllocation,
            ),
          ],
        ),
      ),
      const Heading('Família'),
      Summary(
        income: month.income(Pocket.family, actual: actual),
        costs: month.costs(Pocket.family, actual: actual),
        color: familyColor,
      ),
      if (f < 0)
        const Panel(
          color: Color(0xFFFFECCD),
          child: Text(
            'Os gastos da casa passaram das entradas. Reveja os limites e as próximas contas.',
          ),
        ),
      for (final item in month.items.where(
        (i) =>
            i.pocket == Pocket.family && i.group == Group.variable && i.track,
      ))
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            '${item.name}: ${money(item.amount - month.spent(item.id))} no limite.',
          ),
        ),
      const SizedBox(height: 20),
      const Heading(
        'Negócio nos últimos meses',
        subtitle: 'Verde: sobrou • vermelho: faltou',
      ),
      Panel(
        child: Column(
          children: [
            for (final key in recent)
              Builder(
                builder: (_) {
                  final m = data.months[key]!,
                      value = data.months[key]!.balance(
                        Pocket.business,
                        actual: actual,
                      );
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${DateFormat('MMM yyyy', 'pt_BR').format(m.date)} · ${value >= 0 ? 'Sobrou' : 'Faltou'} ${money(value.abs())}',
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: value.abs() / maximum,
                          color: value >= 0 ? businessColor : fixedColor,
                          backgroundColor: const Color(0xFFF1F3ED),
                          minHeight: 14,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
      reservePanel(),
    ];
  }

  Widget resultLine(String label, int value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 16,
      runSpacing: 4,
      children: [
        Text(label),
        Text(money(value), style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );

  Future<void> editWithdrawal() async {
    final values = await numberForm(
      'Retirada da família',
      ['Valor mensal (R\$)', 'Dia do mês'],
      [editableMoney(month.withdrawal), '${month.withdrawalDay}'],
      dayIndex: 1,
    );
    if (values == null) return;
    final amount = parseMoney(values[0])!, day = int.parse(values[1]);
    if ((amount != month.withdrawal || day != month.withdrawalDay) &&
        month.paid.contains('withdrawal')) {
      if (!mounted ||
          !await confirm(
            context,
            'Atualizar retirada?',
            'A retirada será desmarcada na agenda para você conferir o novo valor e dia.',
          )) {
        return;
      }
      month.paid.remove('withdrawal');
    }
    month.withdrawal = amount;
    month.withdrawalDay = day;
    await save();
  }

  Future<void> editReserve() async {
    final values = await numberForm(
      'Reserva do negócio',
      [
        'Meta (R\$)',
        'Saldo já guardado (R\$)',
        'Quanto guardar por mês (R\$)',
        'Separar neste mês (R\$)',
      ],
      [
        editableMoney(data.reserveGoal),
        editableMoney(data.reserveSaved),
        editableMoney(data.reserveMonthly),
        editableMoney(month.reserveAllocation),
      ],
    );
    if (values == null) return;
    data.reserveGoal = parseMoney(values[0])!;
    data.reserveSaved = parseMoney(values[1])!;
    data.reserveMonthly = parseMoney(values[2])!;
    month.reserveAllocation = parseMoney(values[3])!;
    await save();
  }

  Future<List<String>?> numberForm(
    String title,
    List<String> labels,
    List<String> initial, {
    int? dayIndex,
  }) async {
    final controllers = initial
        .map((v) => TextEditingController(text: v))
        .toList();
    final form = GlobalKey<FormState>();
    final result = await showDialog<List<String>>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 440,
          child: Form(
            key: form,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TextFormField(
                        controller: controllers[i],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(labelText: labels[i]),
                        validator: i == dayIndex
                            ? (s) =>
                                  (int.tryParse(s ?? '') ?? 0) < 1 ||
                                      (int.tryParse(s ?? '') ?? 32) > 31
                                  ? 'Use um dia entre 1 e 31'
                                  : null
                            : nonNegativeMoney,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(c, controllers.map((c) => c.text).toList());
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    // Aguarda a animação do diálogo antes de descartar os controladores.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final c in controllers) {
      c.dispose();
    }
    return result;
  }

  Future<void> addAgenda() async {
    Pocket p = Pocket.business;
    Group g = Group.occasional;
    final result = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => AlertDialog(
          title: const Text('Conta ou recebimento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Pocket>(
                initialValue: p,
                decoration: const InputDecoration(labelText: 'Bolso'),
                items: Pocket.values
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text(pocketName(v)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => update(() => p = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<Group>(
                initialValue: g,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items:
                    [
                          Group.income,
                          Group.fixed,
                          Group.installment,
                          Group.occasional,
                        ]
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text(groupName(v)),
                          ),
                        )
                        .toList(),
                onChanged: (v) => update(() => g = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
    if (result == true) await edit(p, g);
  }

  Future<void> options(String option) async {
    if (option == 'demo') {
      if (!await confirm(
        context,
        'Explorar demonstração?',
        'Carregar os valores fictícios de outubro de 2026? Você poderá sair da demonstração pelo menu.',
      )) {
        return;
      }
      widget.store.data = demoData();
      selected = DateTime(2026, 10);
      await save();
      return;
    }
    if (option == 'clearDemo') {
      if (!await confirm(
        context,
        'Sair da demonstração?',
        'Os exemplos e suas alterações na demonstração serão removidos. O app começará vazio.',
      )) {
        return;
      }
      widget.store.data = FinanceData();
      selected = DateTime(DateTime.now().year, DateTime.now().month);
      await save();
      return;
    }
    if (option == 'backup') {
      try {
        await Clipboard.setData(ClipboardData(text: data.encode()));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Backup copiado. Cole em um arquivo e guarde em local seguro.',
              ),
            ),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Não foi possível acessar a área de transferência.',
              ),
            ),
          );
        }
      }
      return;
    }
    final controller = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Restaurar backup'),
        content: SizedBox(
          width: 460,
          child: TextField(
            controller: controller,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Cole o conteúdo do backup',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, controller.text),
            child: const Text('Verificar backup'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (raw == null || !mounted) return;
    try {
      final restored = FinanceData.decode(raw);
      if (!await confirm(
        context,
        'Substituir os dados atuais?',
        'Restaurar ${restored.months.length} mês(es)? Esta ação substitui os registros neste dispositivo.',
      )) {
        return;
      }
      widget.store.data = restored;
      await save();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup inválido. Nenhum dado foi substituído.'),
          ),
        );
      }
    }
  }
}
