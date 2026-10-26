import 'package:flutter/material.dart';
import '../domain/finance.dart';
import 'finance_widgets.dart';

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

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      '${widget.item == null ? 'Adicionar' : 'Editar'} · ${groupName(widget.group)}',
    ),
    content: SizedBox(
      width: 460,
      child: Form(
        key: form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Descrição'),
                textCapitalization: TextCapitalization.sentences,
                validator: (s) => s == null || s.trim().isEmpty
                    ? 'Dê um nome para este item'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: widget.group == Group.variable
                      ? 'Limite do mês (R\$)'
                      : 'Valor total do mês (R\$)',
                ),
                validator: positiveMoney,
              ),
              if (widget.group != Group.variable) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: days,
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(
                    labelText: 'Dias do mês',
                    helperText:
                        'Ex.: 10, 25. O valor é dividido entre os dias.',
                  ),
                  validator: (s) {
                    final values = (s ?? '')
                        .split(',')
                        .map((s) => int.tryParse(s.trim()))
                        .toList();
                    return values.any((d) => d == null || d < 1 || d > 31) ||
                            values.toSet().length != values.length
                        ? 'Use dias únicos de 1 a 31, separados por vírgula'
                        : null;
                  },
                ),
              ],
              if (widget.group == Group.installment) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: part,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Parcela atual'),
                  validator: (s) => (int.tryParse(s ?? '') ?? 0) < 1
                      ? 'Informe a parcela atual'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: parts,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Total de parcelas',
                  ),
                  validator: (s) =>
                      (int.tryParse(s ?? '') ?? 0) <
                          (int.tryParse(part.text) ?? 1)
                      ? 'Total deve ser maior ou igual à parcela atual'
                      : null,
                ),
              ],
              if (widget.group == Group.variable)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: track,
                  onChanged: (v) => setState(() => track = v!),
                  title: const Text('Acompanhar este limite'),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (!form.currentState!.validate()) return;
          final selectedDays =
              widget.group == Group.variable
                    ? [1]
                    : days.text
                          .split(',')
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
        },
        child: const Text('Salvar'),
      ),
    ],
  );
}
