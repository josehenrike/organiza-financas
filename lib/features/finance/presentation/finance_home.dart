import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../data/demo_data.dart';
import '../data/finance_store.dart';
import '../domain/finance.dart';
import 'finance_widgets.dart';
import 'item_form.dart';
import 'limit_page.dart';

const _groupIcons = {
  Group.income: Icons.payments_outlined,
  Group.fixed: Icons.event_repeat,
  Group.installment: Icons.credit_card,
  Group.variable: Icons.shopping_basket_outlined,
  Group.occasional: Icons.bolt_outlined,
};

const _emptyHints = {
  Pocket.business: {
    Group.income: 'Nada ainda. Ex.: venda de leite, feira, ovos.',
    Group.fixed: 'Nada ainda. Ex.: diarista, energia do curral.',
    Group.installment: 'Nada ainda. Ex.: Pronaf, máquina parcelada.',
    Group.variable: 'Nada ainda. Ex.: ração, adubo, combustível.',
    Group.occasional: 'Nada ainda. Ex.: conserto de cerca, frete.',
  },
  Pocket.family: {
    Group.income: 'Ex.: diárias fora, aposentadoria, Bolsa Família.',
    Group.fixed: 'Nada ainda. Ex.: energia e água, internet, escola.',
    Group.installment: 'Nada ainda. Ex.: moto, geladeira.',
    Group.variable: 'Nada ainda. Ex.: mercado, gás, farmácia.',
    Group.occasional: 'Nada ainda. Ex.: presente, consulta.',
  },
};

class FinanceHome extends StatefulWidget {
  const FinanceHome({super.key, required this.store});
  final FinanceStore store;
  @override
  State<FinanceHome> createState() => _FinanceHomeState();
}

class _FinanceHomeState extends State<FinanceHome> {
  int tab = 0;
  late DateTime selected = currentMonth;
  Pocket? agendaPocket;
  bool actual = false;
  String? saveError;
  final scroll = ScrollController();

  /// O botão flutuante encolhe ao rolar para baixo, para não cobrir o conteúdo.
  bool fabExtended = true;

  /// Mês exibido que ainda não foi gravado. Só passa a existir nos dados
  /// quando o usuário altera algo, então navegar não cria meses.
  MonthPlan? _draft;
  FinanceData? _draftOf;

  static DateTime get currentMonth =>
      DateTime(DateTime.now().year, DateTime.now().month);
  FinanceData get data => widget.store.data;
  MonthPlan get month {
    final key = monthKey(selected);
    final saved = data.months[key];
    if (saved != null) return saved;
    if (_draft?.key != key || !identical(_draftOf, data)) {
      _draft = data.preview(key);
      _draftOf = data;
    }
    return _draft!;
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final current = month;
    data.months.putIfAbsent(current.key, () => current);
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
    setState(() {
      tab = index;
      fabExtended = true;
    });
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  void changeMonth(DateTime month) => setState(() => selected = month);

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

  Future<void> deleteItem(PlanItem item) async {
    final m = month;
    final spending = m.spending.where((s) => s.itemId == item.id).toList();
    if (!await confirm(
      context,
      'Excluir ${item.name}?',
      spending.isEmpty
          ? 'O item sai do planejamento deste mês.'
          : 'O item e ${spending.length} gasto(s) registrado(s) nele saem deste mês.',
      action: 'Excluir',
      destructive: true,
    )) {
      return;
    }
    final index = m.items.indexOf(item);
    final paid = m.paid.where((id) => id.startsWith('${item.id}:')).toList();
    m.items.remove(item);
    m.spending.removeWhere((s) => s.itemId == item.id);
    m.paid.removeAll(paid);
    await save();
    if (!mounted) return;
    notify(
      context,
      '${item.name} excluído.',
      action: SnackBarAction(
        label: 'Desfazer',
        onPressed: () {
          m.items.insert(min(index, m.items.length), item);
          m.spending.addAll(spending);
          m.paid.addAll(paid);
          save();
        },
      ),
    );
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
    final c = context.colors;
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final content = switch (tab) {
      0 => registration(),
      1 => planning(Pocket.business),
      2 => planning(Pocket.family),
      3 => agenda(),
      _ => results(),
    };
    final source = data.sourceOf(month.key);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.spa_outlined, color: tab == 2 ? c.family : c.business),
            const SizedBox(width: 10),
            const Flexible(child: Text('Organiza Finanças')),
            if (data.demo) ...[
              const SizedBox(width: 10),
              Tooltip(
                message: 'Valores fictícios. Saia pelo menu de opções.',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: c.warningSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Demonstração',
                    style: TextStyle(
                      color: c.onWarningSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: monthBar(),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Opções e cópia de segurança',
            onSelected: options,
            itemBuilder: (_) => [
              menuItem('backup', Icons.copy_outlined, 'Copiar backup'),
              menuItem('restore', Icons.restore, 'Restaurar backup'),
              if (data.isEmpty)
                menuItem('demo', Icons.school_outlined, 'Explorar exemplo'),
              if (data.demo)
                menuItem('clearDemo', Icons.logout, 'Sair da demonstração'),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: quickSpend,
        isExtended: fabExtended,
        tooltip: 'Registrar gasto',
        icon: const Icon(Icons.add),
        label: const Text('Registrar gasto'),
      ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              selectedIndex: tab,
              onDestinationSelected: go,
              labelType: NavigationRailLabelType.all,
              leading: const SizedBox(height: 12),
              destinations: destinations
                  .map(
                    (d) => NavigationRailDestination(
                      icon: Icon(d.$2),
                      selectedIcon: Icon(d.$3),
                      label: Text(d.$1),
                    ),
                  )
                  .toList(),
            ),
          Expanded(
            child: Column(
              children: [
                if (saveError != null)
                  MaterialBanner(
                    backgroundColor: c.warningSurface,
                    leading: Icon(Icons.error_outline, color: c.danger),
                    content: Text(saveError!),
                    actions: [
                      TextButton(
                        onPressed: save,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                Expanded(
                  child: NotificationListener<UserScrollNotification>(
                    onNotification: (n) {
                      final extend =
                          n.direction == ScrollDirection.forward ||
                          n.metrics.pixels <= 0;
                      if (n.direction != ScrollDirection.idle &&
                          extend != fabExtended) {
                        setState(() => fabExtended = extend);
                      }
                      return false;
                    },
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1040),
                        child: ListView(
                          controller: scroll,
                          padding: EdgeInsets.fromLTRB(
                            wide ? 32 : 16,
                            wide ? 32 : 20,
                            wide ? 32 : 16,
                            24,
                          ),
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              layoutBuilder: (current, previous) => Stack(
                                alignment: Alignment.topCenter,
                                children: [...previous, ?current],
                              ),
                              child: Column(
                                key: ValueKey('$tab ${month.key}'),
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (source != null)
                                    Notice(
                                      'Mês ainda não iniciado. Mostrando o planejamento '
                                      'repetido de ${monthTitle(data.months[source]!.date).toLowerCase()}, '
                                      'com parcelas avançadas. Ele é salvo na primeira alteração.',
                                      icon: Icons.auto_awesome_outlined,
                                    ),
                                  ...content,
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.phone_android,
                                  size: 16,
                                  color: c.muted,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Dados neste dispositivo • Sem sincronização em nuvem',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: c.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Espaço para o botão flutuante não cobrir o fim.
                            const SizedBox(height: 88),
                          ],
                        ),
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
                    (d) => NavigationDestination(
                      icon: Icon(d.$2),
                      selectedIcon: Icon(d.$3),
                      label: d.$1,
                    ),
                  )
                  .toList(),
            ),
    );
  }

  PopupMenuItem<String> menuItem(String value, IconData icon, String label) =>
      PopupMenuItem(
        value: value,
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 12),
            Text(label),
          ],
        ),
      );

  static const destinations = [
    ('Cadastro', Icons.edit_note, Icons.edit_note),
    ('Negócio', Icons.agriculture_outlined, Icons.agriculture),
    ('Família', Icons.home_outlined, Icons.home),
    ('Agenda', Icons.calendar_month_outlined, Icons.calendar_month),
    ('Resultado', Icons.bar_chart_outlined, Icons.bar_chart),
  ];

  Widget monthBar() {
    final c = context.colors;
    final isCurrent = selected == currentMonth;
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: c.panel,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Mês anterior',
            onPressed: () =>
                changeMonth(DateTime(selected.year, selected.month - 1)),
            icon: const Icon(Icons.chevron_left),
          ),
          Flexible(
            child: Tooltip(
              message: 'Escolher mês',
              child: InkWell(
                onTap: pickMonth,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          monthTitle(selected),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 22),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Próximo mês',
            onPressed: () =>
                changeMonth(DateTime(selected.year, selected.month + 1)),
            icon: const Icon(Icons.chevron_right),
          ),
          if (!isCurrent)
            TextButton(
              onPressed: () => changeMonth(currentMonth),
              child: const Text('Hoje'),
            ),
        ],
      ),
    );
  }

  /// Grade de meses para pular direto para qualquer mês.
  Future<void> pickMonth() async {
    var year = selected.year;
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, update) {
          final colors = c.colors;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Ano anterior',
                        onPressed: () => update(() => year--),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text(
                        '$year',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Próximo ano',
                        onPressed: () => update(() => year++),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    childAspectRatio: 1.7,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (var m = 1; m <= 12; m++)
                        monthCell(c, DateTime(year, m), colors),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sublinhado: mês atual • ponto: mês com registros.',
                    style: TextStyle(color: colors.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (picked != null) changeMonth(picked);
  }

  Widget monthCell(BuildContext c, DateTime date, FinanceColors colors) {
    final isSelected = date == selected;
    final saved = data.months.containsKey(monthKey(date));
    final label = DateFormat.MMM('pt_BR').format(date).replaceAll('.', '');
    return Material(
      color: isSelected ? colors.businessFill : colors.businessTint,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pop(c, date),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label[0].toUpperCase() + label.substring(1),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : null,
                decoration: date == currentMonth
                    ? TextDecoration.underline
                    : null,
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: saved
                    ? (isSelected ? Colors.white : colors.business)
                    : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> registration() {
    final c = context.colors;
    final m = month;
    final steps = [
      (
        'Cadastre as rendas',
        m.items.any((i) => i.group == Group.income),
        null as VoidCallback?,
      ),
      ('Combine a retirada da família', m.withdrawal > 0, editWithdrawal),
      ('Defina a reserva do negócio', data.reserveGoal > 0, editReserve),
      (
        'Planeje os gastos do mês',
        m.items.any((i) => i.group != Group.income),
        () => go(1),
      ),
    ];
    final done = steps.where((s) => s.$2).length;
    return [
      const Heading(
        'Cada dinheiro no seu lugar',
        subtitle: 'Cuide da roça e da casa, um passo de cada vez.',
      ),
      if (done < steps.length)
        Panel(
          color: c.businessTint,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.eco_outlined, color: c.business, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      done == 0 ? 'Vamos começar' : 'Primeiros passos',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '$done de ${steps.length}',
                    style: TextStyle(
                      color: c.business,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Meter(
                ratio: done / steps.length,
                color: c.business,
                warn: false,
                height: 6,
                background: c.panel,
              ),
              const SizedBox(height: 8),
              for (final (i, step) in steps.indexed)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: step.$3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          step.$2
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: step.$2 ? c.business : c.muted,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${i + 1}. ${step.$1}',
                            style: TextStyle(
                              decoration: step.$2
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: step.$2 ? c.muted : null,
                            ),
                          ),
                        ),
                        if (!step.$2 && step.$3 != null)
                          Icon(Icons.chevron_right, color: c.muted),
                      ],
                    ),
                  ),
                ),
              if (data.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton.icon(
                    onPressed: () => options('demo'),
                    icon: const Icon(Icons.school_outlined),
                    label: const Text('Conhecer o app com exemplos'),
                  ),
                ),
            ],
          ),
        ),
      Pair(
        section(Pocket.business, Group.income),
        section(Pocket.family, Group.income),
      ),
      Pair(withdrawalPanel(), reservePanel()),
      FilledButton.icon(
        onPressed: () => go(1),
        icon: const Icon(Icons.arrow_forward),
        label: const Text('Continuar: planejar o negócio'),
      ),
    ];
  }

  Widget withdrawalPanel() {
    final c = context.colors;
    final m = month;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardTitle(
            'A ponte entre a roça e a casa',
            icon: Icons.swap_horiz,
            color: c.family,
          ),
          const SizedBox(height: 12),
          Text(
            'A retirada sai do caixa do negócio e entra automaticamente como renda da família.',
            style: TextStyle(color: c.muted),
          ),
          const SizedBox(height: 16),
          Text(
            money(m.withdrawal),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          Text(
            m.withdrawal == 0
                ? 'Ainda não combinada'
                : 'Todo dia ${m.withdrawalDay}',
            style: TextStyle(color: c.muted),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: editWithdrawal,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Combinar retirada'),
          ),
        ],
      ),
    );
  }

  List<Widget> planning(Pocket p) {
    final m = month;
    final tracked = m.items
        .where((i) => i.pocket == p && i.group == Group.variable && i.track)
        .toList();
    return [
      Heading(
        p == Pocket.business ? 'O negócio da família' : 'A família e a casa',
        subtitle:
            'Valores previstos do mês, mais os gastos variáveis já registrados.',
      ),
      if (p == Pocket.business && (m.withdrawal > 0 || m.reserveAllocation > 0))
        Pair(
          Summary(
            income: m.income(p),
            costs: m.costs(p),
            color: context.pocketFill(p),
          ),
          Panel(
            child: Column(
              children: [
                resultLine('Resultado do negócio', m.balance(p)),
                resultLine('Retirada para a família', -m.withdrawal),
                resultLine('Reserva planejada', -m.reserveAllocation),
                const Divider(height: 16),
                resultLine(
                  'Fica no caixa',
                  m.balance(p) - m.withdrawal - m.reserveAllocation,
                  bold: true,
                ),
              ],
            ),
          ),
        )
      else
        Summary(
          income: m.income(p),
          costs: m.costs(p),
          color: context.pocketFill(p),
        ),
      if (tracked.isNotEmpty) ...[
        const Heading(
          'De olho nos limites',
          subtitle: 'Toque em uma categoria para registrar um gasto.',
          small: true,
        ),
        for (var i = 0; i < tracked.length; i += 2)
          Pair(
            limitCard(tracked[i]),
            i + 1 < tracked.length
                ? limitCard(tracked[i + 1])
                : const SizedBox.shrink(),
          ),
      ],
      section(p, Group.income),
      const Heading('Gastos que não mudam', small: true),
      Pair(section(p, Group.fixed), section(p, Group.installment)),
      const Heading('Gastos que mudam', small: true),
      Pair(section(p, Group.variable), section(p, Group.occasional)),
      FilledButton.icon(
        onPressed: () => go(3),
        icon: const Icon(Icons.calendar_month),
        label: const Text('Ver agenda do mês'),
      ),
    ];
  }

  Widget limitCard(PlanItem item) {
    final c = context.colors;
    final spent = month.spent(item.id), left = item.amount - spent;
    final ratio = spent / max(1, item.amount);
    final alert = ratio >= .8;
    return Panel(
      onTap: () => openLimit(item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.add_circle_outline, color: c.muted),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            left < 0
                ? '${money(-left)} acima do limite'
                : '${money(left)} disponíveis',
            style: TextStyle(
              color: alert ? c.danger : context.pocketColor(item.pocket),
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 10),
          Meter(ratio: ratio, color: context.pocketColor(item.pocket)),
          const SizedBox(height: 8),
          Text(
            'Gastou ${money(spent)} de ${money(item.amount)}${alert && left >= 0 ? ' · atenção ao limite' : ''}',
            style: TextStyle(color: c.muted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Color groupColor(Pocket p, Group g) => switch (g) {
    Group.income => context.pocketColor(p),
    Group.fixed || Group.installment => context.colors.danger,
    _ => context.colors.warning,
  };

  Widget section(Pocket p, Group g) {
    final c = context.colors;
    final m = month;
    final items = m.items.where((i) => i.pocket == p && i.group == g).toList();
    final familyIncome = p == Pocket.family && g == Group.income;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardTitle(
            '${groupName(g)}${tab == 0 ? ' · ${pocketName(p)}' : ''}',
            icon: _groupIcons[g]!,
            color: groupColor(p, g),
            trailing: money(m.groupTotal(p, g)),
          ),
          if (g == Group.variable)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Total já gasto. Toque em uma categoria para registrar gastos.',
                style: TextStyle(color: c.muted, fontSize: 14),
              ),
            ),
          const SizedBox(height: 8),
          if (familyIncome)
            itemRow(
              title: 'Retirada do negócio',
              subtitle: m.withdrawal == 0
                  ? 'Toque para combinar'
                  : 'Todo dia ${m.withdrawalDay} · transferência do negócio',
              amount: m.withdrawal,
              onTap: editWithdrawal,
              leading: Icons.swap_horiz,
            ),
          if (items.isEmpty && !familyIncome)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, size: 18, color: c.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _emptyHints[p]![g]!,
                      style: TextStyle(color: c.muted, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          for (final item in items) variableOrPlainRow(item),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => edit(p, g),
            icon: const Icon(Icons.add),
            label: Text(
              g == Group.income
                  ? 'Adicionar renda'
                  : g == Group.variable
                  ? 'Adicionar categoria'
                  : 'Adicionar item',
            ),
          ),
        ],
      ),
    );
  }

  Widget variableOrPlainRow(PlanItem item) {
    final m = month;
    final g = item.group;
    if (g != Group.variable) {
      return itemRow(
        title: item.name,
        subtitle:
            '${daysLabel(item.days)}${g == Group.installment ? ' · parcela ${item.part} de ${item.parts}' : ''}',
        amount: item.amount,
        onTap: () => edit(item.pocket, g, item),
        menu: itemMenu(item),
      );
    }
    final spent = m.spent(item.id);
    final ratio = spent / max(1, item.amount);
    return itemRow(
      title: item.name,
      subtitle:
          'Limite ${money(item.amount)} · ${(ratio * 100).round()}% usado',
      amount: spent,
      onTap: () => openLimit(item),
      menu: itemMenu(item),
      leading: item.track ? Icons.push_pin : null,
      meter: Meter(ratio: ratio, color: context.colors.warning, height: 5),
    );
  }

  Widget itemRow({
    required String title,
    required String subtitle,
    required int amount,
    required VoidCallback onTap,
    Widget? menu,
    IconData? leading,
    Widget? meter,
  }) {
    final c = context.colors;
    return Column(
      children: [
        const Divider(),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: EdgeInsets.fromLTRB(0, 12, menu == null ? 8 : 0, 12),
            child: Row(
              children: [
                if (leading != null) ...[
                  Icon(leading, size: 18, color: c.muted),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(color: c.muted, fontSize: 14),
                      ),
                      if (meter != null) ...[const SizedBox(height: 8), meter],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  money(amount),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (menu == null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(Icons.edit_outlined, size: 20, color: c.muted),
                  )
                else
                  menu,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget itemMenu(PlanItem item) {
    final variable = item.group == Group.variable;
    return PopupMenuButton<String>(
      tooltip: 'Opções de ${item.name}',
      onSelected: (v) async {
        switch (v) {
          case 'edit':
            await edit(item.pocket, item.group, item);
          case 'spend':
            await openLimit(item);
          case 'track':
            item.track = !item.track;
            await save();
          case 'delete':
            await deleteItem(item);
        }
      },
      itemBuilder: (_) => [
        if (variable) menuItem('spend', Icons.add, 'Registrar gasto'),
        menuItem('edit', Icons.edit_outlined, 'Editar'),
        if (variable)
          menuItem(
            'track',
            item.track ? Icons.push_pin_outlined : Icons.push_pin,
            item.track ? 'Tirar do destaque' : 'Destacar no topo',
          ),
        menuItem('delete', Icons.delete_outline, 'Excluir'),
      ],
    );
  }

  Widget reservePanel() {
    final c = context.colors;
    final m = month;
    final missing = max(0, data.reserveGoal - data.reserveSaved);
    final months = data.reserveMonthly > 0
        ? (missing / data.reserveMonthly).ceil()
        : null;
    Widget stat(String label, int value) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: c.muted, fontSize: 14)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              money(value),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
          ),
        ],
      ),
    );
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardTitle('Reserva do negócio', icon: Icons.savings_outlined),
          const SizedBox(height: 8),
          Text(
            'Um dinheiro guardado para a roça não parar.',
            style: TextStyle(color: c.muted),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              stat('Meta', data.reserveGoal),
              stat('Guardado', data.reserveSaved),
              stat('Falta', missing),
            ],
          ),
          const SizedBox(height: 12),
          Meter(
            ratio: data.reserveGoal == 0
                ? 0
                : data.reserveSaved / data.reserveGoal,
            color: c.business,
            warn: false,
          ),
          const SizedBox(height: 12),
          Text(
            data.reserveGoal == 0
                ? 'Defina uma meta para começar.'
                : missing == 0
                ? 'Meta alcançada!'
                : months == null
                ? 'Defina quanto pretende guardar por mês.'
                : 'Guardando ${money(data.reserveMonthly)} por mês, faltam $months ${months == 1 ? 'depósito' : 'depósitos'}.',
          ),
          if (m.reserveAllocation > 0) ...[
            const SizedBox(height: 12),
            if (m.reserveDeposited)
              Row(
                children: [
                  Icon(Icons.check_circle, color: c.business, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Depósito de ${money(m.reserveAllocation)} deste mês registrado.',
                    ),
                  ),
                  TextButton(
                    onPressed: undoDeposit,
                    child: const Text('Desfazer'),
                  ),
                ],
              )
            else
              Text(
                'Separar neste mês: ${money(m.reserveAllocation)}.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: editReserve,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Ajustar reserva'),
              ),
              if (m.reserveAllocation > 0 && !m.reserveDeposited)
                FilledButton.tonalIcon(
                  onPressed: deposit,
                  icon: const Icon(Icons.savings),
                  label: const Text('Já guardei'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> deposit() async {
    final m = month;
    data.reserveSaved += m.reserveAllocation;
    m.reserveDeposited = true;
    await save();
    if (mounted) {
      notify(context, '${money(m.reserveAllocation)} somados ao guardado.');
    }
  }

  Future<void> undoDeposit() async {
    final m = month;
    data.reserveSaved = max(0, data.reserveSaved - m.reserveAllocation);
    m.reserveDeposited = false;
    await save();
  }

  bool overdue(AgendaEntry e) {
    if (month.isPaid(e)) return false;
    final now = DateTime.now(), current = monthKey(now);
    final cmp = month.key.compareTo(current);
    return cmp < 0 || (cmp == 0 && e.day < now.day);
  }

  List<Widget> agenda() {
    final c = context.colors;
    final m = month;
    final entries = m.agenda
        .where((e) => agendaPocket == null || e.pocket == agendaPocket)
        .toList();
    final counted = entries.where((e) => agendaPocket != null || !e.transfer);
    final pending = counted.where((e) => !m.isPaid(e));
    final toPay = pending
        .where((e) => !e.income)
        .fold(0, (v, e) => v + e.amount);
    final toReceive = pending
        .where((e) => e.income)
        .fold(0, (v, e) => v + e.amount);
    final late = entries.where(overdue).map((e) => e.id).toSet().length;
    final now = DateTime.now();
    final last = DateTime(selected.year, selected.month + 1, 0).day;
    Widget stat(String label, String value, Color color) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: c.muted, fontSize: 14)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
    return [
      const Heading(
        'O mês, semana a semana',
        subtitle:
            'Contas e recebimentos vêm do planejamento. Toque no dia para marcar como pago ou recebido.',
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
      const SizedBox(height: 16),
      Panel(
        child: Row(
          children: [
            stat('A receber', money(toReceive), c.business),
            stat('A pagar', money(toPay), c.danger),
            stat('Atrasados', '$late', late > 0 ? c.danger : c.muted),
          ],
        ),
      ),
      for (var week = 0; week < 4; week++)
        Builder(
          builder: (context) {
            final start = week * 7 + 1, end = week == 3 ? last : week * 7 + 7;
            final rows = entries
                .where((e) => e.day >= start && e.day <= end)
                .toList();
            final totals = rows.where(
              (e) => agendaPocket != null || !e.transfer,
            );
            final income = totals
                .where((e) => e.income)
                .fold(0, (v, e) => v + e.amount);
            final costs = totals
                .where((e) => !e.income)
                .fold(0, (v, e) => v + e.amount);
            final current =
                monthKey(now) == m.key && now.day >= start && now.day <= end;
            return Panel(
              padding: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      Text(
                        'Semana ${week + 1}',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'dias $start a $end',
                        style: TextStyle(color: c.muted),
                      ),
                      if (current)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: c.businessTint,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'esta semana',
                            style: TextStyle(
                              color: c.business,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Nenhuma conta ou recebimento nesta semana.',
                        style: TextStyle(color: c.muted),
                      ),
                    ),
                  for (final e in rows) agendaRow(e),
                  if (rows.isNotEmpty) ...[
                    const Divider(height: 24),
                    Wrap(
                      spacing: 20,
                      runSpacing: 6,
                      children: [
                        Text('Entra ${money(income)}'),
                        Text('Sai ${money(costs)}'),
                        Text(
                          '${income >= costs ? 'Sobra' : 'Falta'} ${money((income - costs).abs())}',
                          style: TextStyle(
                            color: income >= costs ? c.business : c.danger,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      if (agendaPocket == null)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            'Em “Tudo”, a retirada não entra nos totais: ela só muda o dinheiro de bolso.',
            style: TextStyle(color: c.muted, fontSize: 14),
          ),
        ),
      FilledButton.icon(
        onPressed: addAgenda,
        icon: const Icon(Icons.add),
        label: const Text('Conta ou recebimento'),
      ),
    ];
  }

  Widget agendaRow(AgendaEntry e) {
    final c = context.colors;
    final m = month;
    final paid = m.isPaid(e), spend = e.id.startsWith('spend:');
    final late = overdue(e);
    void toggle() {
      paid ? m.paid.remove(e.id) : m.paid.add(e.id);
      save();
    }

    final status = spend
        ? 'registrado'
        : paid
        ? (e.income ? 'recebido' : 'pago')
        : late
        ? 'atrasado'
        : 'pendente';
    final done = paid && !spend;
    return Semantics(
      checked: spend ? null : paid,
      button: !spend,
      label: '${e.name}, dia ${e.day}, $status',
      excludeSemantics: true,
      child: InkWell(
        onTap: spend ? null : toggle,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: done
                      ? context.pocketFill(e.pocket)
                      : context.pocketTint(e.pocket),
                  borderRadius: BorderRadius.circular(12),
                  border: late ? Border.all(color: c.danger, width: 1.6) : null,
                ),
                child: done
                    ? const Icon(Icons.check, color: Colors.white)
                    : Text(
                        '${e.day}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: late
                              ? c.danger
                              : context.pocketColor(e.pocket),
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
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: done ? c.muted : null,
                      ),
                    ),
                    Text(
                      '${done ? 'Dia ${e.day} · ' : ''}${pocketName(e.pocket)}${e.transfer ? ' · transferência' : ''} · $status',
                      style: TextStyle(
                        color: late ? c.danger : c.muted,
                        fontSize: 13,
                        fontWeight: late ? FontWeight.w700 : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${e.income ? '+' : '−'} ${money(e.amount)}',
                style: TextStyle(
                  color: done ? c.muted : (e.income ? c.business : c.danger),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> results() {
    final c = context.colors;
    final m = month;
    final b = m.balance(Pocket.business, actual: actual),
        f = m.balance(Pocket.family, actual: actual);
    final income = m.income(Pocket.business, actual: actual);
    final withdrawal = actual && !m.paid.contains('withdrawal')
        ? 0
        : m.withdrawal;
    final reserve = actual && !m.reserveDeposited ? 0 : m.reserveAllocation;
    final history = {
      ...data.months.keys.where((k) => k.compareTo(m.key) <= 0),
      m.key,
    }.toList()..sort();
    final recent = history.reversed.take(6).toList().reversed.toList();
    MonthPlan monthAt(String k) => k == m.key ? m : data.months[k]!;
    String shortMonth(DateTime d) {
      final t = DateFormat.MMM('pt_BR').format(d).replaceAll('.', '');
      return t[0].toUpperCase() + t.substring(1);
    }

    return [
      const Heading(
        'Sobrou ou faltou?',
        subtitle: 'Entenda o resultado e escolha o próximo passo.',
      ),
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: Text('Planejado')),
          ButtonSegment(value: true, label: Text('Pago e recebido')),
        ],
        selected: {actual},
        onSelectionChanged: (s) => setState(() => actual = s.first),
      ),
      const SizedBox(height: 12),
      Text(
        actual
            ? 'Somente contas e rendas marcadas na agenda, mais os gastos variáveis registrados.'
            : 'Valores previstos do planejamento, mais os gastos variáveis já registrados. Não conta os limites inteiros.',
        style: TextStyle(color: c.muted, fontSize: 14),
      ),
      const SizedBox(height: 20),
      Pair(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Heading('Negócio', small: true),
            Summary(
              income: income,
              costs: m.costs(Pocket.business, actual: actual),
              color: c.businessFill,
              forecast: !actual,
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
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  resultLine('Resultado do negócio', b),
                  resultLine('Retirada para a família', -withdrawal),
                  resultLine(
                    actual ? 'Reserva guardada' : 'Reserva planejada',
                    -reserve,
                  ),
                  const Divider(height: 16),
                  resultLine(
                    'Fica no caixa',
                    b - withdrawal - reserve,
                    bold: true,
                  ),
                ],
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Heading('Família', small: true),
            Summary(
              income: m.income(Pocket.family, actual: actual),
              costs: m.costs(Pocket.family, actual: actual),
              color: c.familyFill,
              forecast: !actual,
            ),
            if (f < 0)
              const Notice(
                'Os gastos da casa passaram das entradas. Reveja os limites e as próximas contas.',
                icon: Icons.warning_amber_rounded,
                warning: true,
              ),
            for (final item in m.items.where(
              (i) =>
                  i.pocket == Pocket.family &&
                  i.group == Group.variable &&
                  i.track,
            ))
              limitCard(item),
          ],
        ),
      ),
      Heading(
        'Negócio nos últimos meses',
        subtitle: recent.length < 2
            ? 'O histórico aparece conforme você usa o app mês a mês.'
            : 'Quanto sobrou ou faltou. O mês exibido fica em destaque.',
        small: true,
      ),
      Panel(
        child: BalanceChart(
          bars: [
            for (final key in recent)
              (
                shortMonth(monthAt(key).date),
                monthAt(key).balance(Pocket.business, actual: actual),
              ),
          ],
        ),
      ),
      reservePanel(),
    ];
  }

  Widget resultLine(String label, int value, {bool bold = false}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
      color: value < 0 && bold ? context.colors.danger : null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: bold ? style : null)),
          const SizedBox(width: 12),
          Text('${value < 0 ? '−' : ''}${money(value.abs())}', style: style),
        ],
      ),
    );
  }

  /// Escolhe uma categoria variável e abre o registro de gasto.
  Future<void> quickSpend() async {
    final m = month;
    final order = tab == 2
        ? [Pocket.family, Pocket.business]
        : [Pocket.business, Pocket.family];
    final picked = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      builder: (c) {
        final colors = c.colors;
        final variables = [
          for (final p in order)
            ...m.items.where((i) => i.pocket == p && i.group == Group.variable),
        ];
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(c).height * .8,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                const Heading(
                  'Onde foi o gasto?',
                  subtitle: 'Escolha a categoria com limite.',
                  small: true,
                ),
                if (variables.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Você ainda não tem categorias de gastos variáveis, como mercado ou combustível. Crie uma para começar:',
                      style: TextStyle(color: colors.muted),
                    ),
                  ),
                for (final item in variables)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: CircleAvatar(
                      backgroundColor: c.pocketTint(item.pocket),
                      foregroundColor: c.pocketColor(item.pocket),
                      child: Icon(pocketIcon(item.pocket), size: 20),
                    ),
                    title: Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${pocketName(item.pocket)} · ${money(item.amount - m.spent(item.id))} disponíveis',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(c, item),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in order)
                      OutlinedButton.icon(
                        onPressed: () => Navigator.pop(c, p),
                        icon: const Icon(Icons.add),
                        label: Text('Nova categoria · ${pocketName(p)}'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    if (picked is PlanItem) await openLimit(picked);
    if (picked is Pocket) await edit(picked, Group.variable);
  }

  Future<void> editWithdrawal() async {
    final m = month;
    final values = await numberForm(
      'Retirada da família',
      ['Valor mensal', 'Dia do mês'],
      [editableMoney(m.withdrawal), '${m.withdrawalDay}'],
      dayIndex: 1,
      help: 'Quanto o negócio passa para a casa todo mês.',
    );
    if (values == null) return;
    final amount = parseMoney(values[0])!, day = int.parse(values[1]);
    if ((amount != m.withdrawal || day != m.withdrawalDay) &&
        m.paid.contains('withdrawal')) {
      if (!mounted ||
          !await confirm(
            context,
            'Atualizar retirada?',
            'A retirada será desmarcada na agenda para você conferir o novo valor e dia.',
          )) {
        return;
      }
      m.paid.remove('withdrawal');
    }
    m.withdrawal = amount;
    m.withdrawalDay = day;
    await save();
  }

  Future<void> editReserve() async {
    final m = month;
    final values = await numberForm(
      'Reserva do negócio',
      ['Meta', 'Já guardado', 'Quanto guardar por mês', 'Separar neste mês'],
      [
        editableMoney(data.reserveGoal),
        editableMoney(data.reserveSaved),
        editableMoney(data.reserveMonthly),
        editableMoney(m.reserveAllocation),
      ],
    );
    if (values == null) return;
    final allocation = parseMoney(values[3])!;
    final resetDeposit =
        m.reserveDeposited && allocation != m.reserveAllocation;
    data.reserveGoal = parseMoney(values[0])!;
    data.reserveSaved = parseMoney(values[1])!;
    data.reserveMonthly = parseMoney(values[2])!;
    m.reserveAllocation = allocation;
    if (resetDeposit) m.reserveDeposited = false;
    await save();
    if (resetDeposit && mounted) {
      notify(
        context,
        'O valor do mês mudou. Toque em “Já guardei” depois de depositar.',
      );
    }
  }

  Future<List<String>?> numberForm(
    String title,
    List<String> labels,
    List<String> initial, {
    int? dayIndex,
    String? help,
  }) async {
    final controllers = initial
        .map((v) => TextEditingController(text: v))
        .toList();
    final form = GlobalKey<FormState>();
    final result = await showDialog<List<String>>(
      context: context,
      builder: (c) {
        void submit() {
          if (form.currentState!.validate()) {
            Navigator.pop(c, controllers.map((c) => c.text).toList());
          }
        }

        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 440,
            child: Form(
              key: form,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (help != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          help,
                          style: TextStyle(color: c.colors.muted),
                        ),
                      ),
                    for (var i = 0; i < labels.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TextFormField(
                          controller: controllers[i],
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: i != dayIndex,
                          ),
                          inputFormatters: i == dayIndex
                              ? [FilteringTextInputFormatter.digitsOnly]
                              : moneyInput,
                          textInputAction: i == labels.length - 1
                              ? TextInputAction.done
                              : TextInputAction.next,
                          onFieldSubmitted: i == labels.length - 1
                              ? (_) => submit()
                              : null,
                          decoration: InputDecoration(
                            labelText: labels[i],
                            prefixText: i == dayIndex ? null : 'R\$ ',
                          ),
                          validator: i == dayIndex
                              ? (s) {
                                  final d = int.tryParse(s ?? '') ?? 0;
                                  return d < 1 || d > 31
                                      ? 'Use um dia entre 1 e 31'
                                      : null;
                                }
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
            FilledButton(onPressed: submit, child: const Text('Salvar')),
          ],
        );
      },
    );
    // Aguarda a animação do diálogo antes de descartar os controladores.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final c in controllers) {
      c.dispose();
    }
    return result;
  }

  Future<void> addAgenda() async {
    Pocket p = agendaPocket ?? Pocket.business;
    Group g = Group.occasional;
    final result = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => AlertDialog(
          title: const Text('Conta ou recebimento'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('De qual bolso?'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final v in Pocket.values)
                      ChoiceChip(
                        avatar: Icon(pocketIcon(v), size: 18),
                        label: Text(pocketName(v)),
                        selected: p == v,
                        onSelected: (_) => update(() => p = v),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Que tipo?'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final v in [
                      Group.income,
                      Group.fixed,
                      Group.installment,
                      Group.occasional,
                    ])
                      ChoiceChip(
                        avatar: Icon(_groupIcons[v], size: 18),
                        label: Text(groupName(v)),
                        selected: g == v,
                        onSelected: (_) => update(() => g = v),
                      ),
                  ],
                ),
              ],
            ),
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
        'Carregar valores fictícios de outubro de 2026? Você pode sair da demonstração pelo menu.',
        action: 'Explorar',
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
        action: 'Sair e limpar',
        destructive: true,
      )) {
        return;
      }
      widget.store.data = FinanceData();
      selected = currentMonth;
      await widget.store.save();
      if (mounted) setState(() {});
      return;
    }
    if (option == 'backup') {
      try {
        await Clipboard.setData(ClipboardData(text: data.encode()));
        if (mounted) {
          notify(
            context,
            'Backup copiado. Cole em um arquivo ou mensagem e guarde em local seguro.',
          );
        }
      } catch (_) {
        if (mounted) {
          notify(context, 'Não foi possível acessar a área de transferência.');
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TextField(
                controller: controller,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Cole o conteúdo do backup',
                  alignLabelWithHint: true,
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  final clip = await Clipboard.getData(Clipboard.kTextPlain);
                  if (clip?.text != null) controller.text = clip!.text!;
                },
                icon: const Icon(Icons.content_paste),
                label: const Text('Colar'),
              ),
            ],
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
      final restored = FinanceData.decode(raw.trim());
      if (!await confirm(
        context,
        'Substituir os dados atuais?',
        'Restaurar ${restored.months.length} mês(es)? Esta ação substitui os registros neste dispositivo.',
        action: 'Substituir',
        destructive: true,
      )) {
        return;
      }
      widget.store.data = restored;
      await widget.store.save();
      if (mounted) {
        setState(() {});
        notify(context, 'Backup restaurado.');
      }
    } catch (_) {
      if (mounted) {
        notify(context, 'Backup inválido. Nenhum dado foi substituído.');
      }
    }
  }
}
