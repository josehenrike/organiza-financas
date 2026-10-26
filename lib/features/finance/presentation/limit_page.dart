import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../domain/finance.dart';
import 'finance_widgets.dart';

class LimitPage extends StatefulWidget {
  const LimitPage({
    super.key,
    required this.item,
    required this.month,
    required this.onSave,
  });
  final PlanItem item;
  final MonthPlan month;
  final Future<void> Function() onSave;
  @override
  State<LimitPage> createState() => _LimitPageState();
}

class _LimitPageState extends State<LimitPage> {
  static final speech = SpeechToText();
  final description = TextEditingController();
  final amount = TextEditingController();
  final form = GlobalKey<FormState>();
  bool voice = false, listening = false, busy = false;
  String? voiceMessage;
  late DateTime date;
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    date = monthKey(now) == widget.month.key
        ? DateTime(now.year, now.month, now.day)
        : widget.month.date;
  }

  @override
  void dispose() {
    speech.cancel();
    description.dispose();
    amount.dispose();
    super.dispose();
  }

  Future<void> listen() async {
    try {
      if (listening) {
        await speech.stop();
        if (mounted) setState(() => listening = false);
        return;
      }
      final available = await speech.initialize();
      if (!mounted) return;
      if (!available) {
        setState(
          () => voiceMessage =
              'Voz indisponível. Você pode digitar nos campos abaixo.',
        );
        return;
      }
      setState(() {
        listening = true;
        voiceMessage =
            'Estou ouvindo. Diga o valor em números e com o que gastou.';
      });
      await speech.listen(
        listenOptions: SpeechListenOptions(
          localeId: 'pt_BR',
          listenFor: const Duration(seconds: 20),
        ),
        onResult: (r) {
          if (!mounted) return;
          final draft = VoiceDraft.parse(r.recognizedWords);
          setState(() {
            description.text = draft.description;
            amount.text = draft.amount == null
                ? ''
                : editableMoney(draft.amount!);
            voice = true;
            if (r.finalResult) {
              listening = false;
              voiceMessage = 'Confira e corrija os campos antes de salvar.';
            }
          });
        },
      );
      Future<void>.delayed(const Duration(seconds: 22), () {
        if (mounted && listening) {
          setState(() {
            listening = false;
            voiceMessage = 'Confira os campos ou tente novamente.';
          });
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          listening = false;
          voiceMessage =
              'Não foi possível ouvir. Verifique a permissão do microfone ou digite.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item, month = widget.month;
    final used = month.spent(item.id),
        left = item.amount - month.spent(item.id);
    final now = DateTime.now();
    final last = DateTime(month.date.year, month.date.month + 1, 0).day;
    final remaining = monthKey(now) == month.key
        ? last - now.day + 1
        : (month.date.isAfter(now) ? last : 0);
    final history = month.spending.where((s) => s.itemId == item.id).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return Scaffold(
      appBar: AppBar(title: Text(item.name)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Heading(
                item.name,
                subtitle:
                    '${pocketName(item.pocket)} · ${monthTitle(month.date)}',
              ),
              Panel(
                color: pocketColor(item.pocket),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      left < 0 ? 'LIMITE ULTRAPASSADO' : 'SALDO DISPONÍVEL',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      money(left),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 20),
                    LinearProgressIndicator(
                      value: (used / max(1, item.amount)).clamp(0, 1),
                      color: Colors.white,
                      backgroundColor: Colors.white24,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Gastou ${money(used)}  •  Limite ${money(item.amount)}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              if (used >= item.amount * .8)
                Panel(
                  color: const Color(0xFFFFECCD),
                  child: Text(
                    'Atenção: ${(used / max(1, item.amount) * 100).round()}% do limite já foi usado.',
                  ),
                ),
              if (remaining > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(
                    'Restam $remaining dias neste mês, contando hoje. Cerca de ${money(max(0, left) ~/ remaining)} por dia.',
                  ),
                ),
              Panel(
                child: Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Registrar um gasto',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: listen,
                        icon: Icon(listening ? Icons.stop : Icons.mic_none),
                        label: Text(
                          listening
                              ? 'Parar de ouvir'
                              : 'Falar: “gastei 50 na padaria”',
                        ),
                      ),
                      if (voiceMessage != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(voiceMessage!),
                        ),
                      if (item.pocket == Pocket.business)
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final label in [
                              'Ração',
                              'Remédio e vacina',
                              'Sal mineral',
                              'Outro',
                            ])
                              ActionChip(
                                label: Text(label),
                                onPressed: () => setState(
                                  () => description.text = label == 'Outro'
                                      ? ''
                                      : label,
                                ),
                              ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: description,
                        decoration: const InputDecoration(
                          labelText: 'Com o quê?',
                          hintText: 'Ex.: mercado',
                        ),
                        validator: (s) => s == null || s.trim().isEmpty
                            ? 'Informe com o que gastou'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: amount,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Valor (R\$)',
                        ),
                        validator: positiveMoney,
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: date,
                            firstDate: month.date,
                            lastDate: DateTime(
                              month.date.year,
                              month.date.month + 1,
                              0,
                            ),
                          );
                          if (selected != null) {
                            setState(() => date = selected);
                          }
                        },
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(DateFormat('dd/MM/yyyy').format(date)),
                      ),
                      FilledButton(
                        onPressed: busy
                            ? null
                            : () async {
                                if (!form.currentState!.validate()) {
                                  return;
                                }
                                if (voice &&
                                    !await confirm(
                                      context,
                                      'Confirmar gasto',
                                      '${description.text}: ${money(parseMoney(amount.text)!)} em ${item.name}?',
                                    )) {
                                  return;
                                }
                                if (!mounted) return;
                                setState(() => busy = true);
                                month.spending.add(
                                  Spending(
                                    id: newId(),
                                    itemId: item.id,
                                    description: description.text.trim(),
                                    amount: parseMoney(amount.text)!,
                                    date: date,
                                    voice: voice,
                                  ),
                                );
                                await widget.onSave();
                                if (!mounted) return;
                                setState(() {
                                  description.clear();
                                  amount.clear();
                                  voice = false;
                                  busy = false;
                                  voiceMessage = null;
                                });
                              },
                        child: const Text('Salvar gasto'),
                      ),
                    ],
                  ),
                ),
              ),
              Heading(
                'Gastos registrados',
                subtitle: '${history.length} lançamento(s)',
              ),
              if (history.isEmpty)
                const Panel(
                  child: Text('Nenhum gasto registrado nesta categoria.'),
                ),
              for (final s in history)
                Panel(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.description,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${DateFormat('dd/MM').format(s.date)}${s.voice ? ' · por voz' : ''}',
                            ),
                            Text(money(s.amount)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Excluir gasto',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          if (!await confirm(
                            context,
                            'Excluir gasto?',
                            '${s.description}: ${money(s.amount)}',
                          )) {
                            return;
                          }
                          month.spending.remove(s);
                          await widget.onSave();
                          if (mounted) setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
