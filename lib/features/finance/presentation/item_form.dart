import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../domain/finance.dart';
import 'finance_widgets.dart';

const _hints = {
  Group.income: 'Dinheiro que entra, como vendas e diárias.',
  Group.fixed: 'Contas que se repetem todo mês com o mesmo valor.',
  Group.installment: 'Compras ou empréstimos pagos em parcelas.',
  Group.variable: 'Gastos que mudam. Defina um limite e registre cada compra.',
  Group.occasional: 'Gastos que acontecem só neste mês.',
};

class ItemForm extends StatefulWidget {
  const ItemForm({
    super.key,
    required this.pocket,
    required this.group,
    this.item,
  });
  final Pocket pocket;
  final Group group;
  final PlanItem? item;
  @override
  State<ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends State<ItemForm> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.item?.name);
  late final amount = TextEditingController(
    text: widget.item == null ? '' : editableMoney(widget.item!.amount),
  );
  late final days = TextEditingController(
    text: widget.item?.days.join(', ') ?? '5',
  );
  late final part = TextEditingController(text: '${widget.item?.part ?? 1}');
  late final parts = TextEditingController(text: '${widget.item?.parts ?? 1}');
  late bool track = widget.item?.track ?? true;
  @override
  void dispose() {
    for (final c in [name, amount, days, part, parts]) {
      c.dispose();
    }
    super.dispose();
  }

  void submit() {
    if (!form.currentState!.validate()) return;
    final selectedDays =
        widget.group == Group.variable
              ? [1]
              : days.text
                    .split(',')
                    .where((s) => s.trim().isNotEmpty)
                    .map((s) => int.parse(s.trim()))
                    .toList()
          ..sort();
    Navigator.pop(
      context,
      PlanItem(
        id: widget.item?.id ?? newId(),
        pocket: widget.pocket,
        group: widget.group,
        name: name.text.trim(),
        amount: parseMoney(amount.text)!,
        days: selectedDays,
        part: int.tryParse(part.text) ?? 1,
        parts: int.tryParse(parts.text) ?? 1,
        track: track,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final digits = [FilteringTextInputFormatter.digitsOnly];
    final title =
        '${widget.item == null ? 'Adicionar' : 'Editar'} · ${groupName(group)}';
    final fields = Form(
      key: form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                pocketIcon(widget.pocket),
                size: 18,
                color: context.pocketColor(widget.pocket),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${pocketName(widget.pocket)} · ${_hints[group]}',
                  style: TextStyle(color: context.colors.muted, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Descrição'),
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            validator: (s) => s == null || s.trim().isEmpty
                ? 'Dê um nome para este item'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: moneyInput,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              prefixText: 'R\$ ',
              labelText: group == Group.variable
                  ? 'Limite do mês'
                  : group == Group.installment
                  ? 'Valor da parcela'
                  : 'Valor total do mês',
            ),
            validator: positiveMoney,
          ),
          if (group != Group.variable) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: days,
              keyboardType: TextInputType.datetime,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d, ]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Dias do mês',
                helperText: 'Ex.: 10, 25. Com vários dias, o valor é dividido.',
              ),
              validator: (s) {
                final values = (s ?? '')
                    .split(',')
                    .where((s) => s.trim().isNotEmpty)
                    .map((s) => int.tryParse(s.trim()))
                    .toList();
                return values.isEmpty ||
                        values.any((d) => d == null || d < 1 || d > 31) ||
                        values.toSet().length != values.length
                    ? 'Use dias únicos de 1 a 31, separados por vírgula'
                    : null;
              },
            ),
          ],
          if (group == Group.installment) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: part,
                    keyboardType: TextInputType.number,
                    inputFormatters: digits,
                    decoration: const InputDecoration(
                      labelText: 'Parcela atual',
                    ),
                    validator: (s) =>
                        (int.tryParse(s ?? '') ?? 0) < 1 ? 'Mínimo 1' : null,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 16, 12, 0),
                  child: Text('de'),
                ),
                Expanded(
                  child: TextFormField(
                    controller: parts,
                    keyboardType: TextInputType.number,
                    inputFormatters: digits,
                    decoration: const InputDecoration(labelText: 'Total'),
                    validator: (s) =>
                        (int.tryParse(s ?? '') ?? 0) <
                            (int.tryParse(part.text) ?? 1)
                        ? 'Menor que a atual'
                        : null,
                  ),
                ),
              ],
            ),
          ],
          if (group == Group.variable)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: track,
              onChanged: (v) => setState(() => track = v),
              title: const Text('Destacar no topo do planejamento'),
              subtitle: const Text('Para acompanhar de perto'),
            ),
        ],
      ),
    );
    // No celular, tela cheia deixa espaço para o teclado.
    if (MediaQuery.sizeOf(context).width < 600) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Cancelar',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(title),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: fields,
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                12 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: FilledButton(
                onPressed: submit,
                child: const Text('Salvar'),
              ),
            ),
          ),
        ),
      );
    }
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(child: fields),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: submit, child: const Text('Salvar')),
      ],
    );
  }
}
