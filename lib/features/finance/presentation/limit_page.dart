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
  final scroll = ScrollController();
  bool voice = false, listening = false, busy = false;
  String? voiceMessage;

  /// Gasto em edição; nulo ao registrar um novo.
  Spending? editing;
  late DateTime date = defaultDate;

  DateTime get defaultDate {
    final now = DateTime.now();
    return monthKey(now) == widget.month.key
        ? DateTime(now.year, now.month, now.day)
        : widget.month.date;
  }

  @override
  void dispose() {
    speech.statusListener = null;
    speech.errorListener = null;
    speech.cancel();
    description.dispose();
    amount.dispose();
    scroll.dispose();
    super.dispose();
  }

  void stopped(String message) {
    if (mounted && listening) {
      setState(() {
        listening = false;
        voiceMessage = message;
      });
    }
  }

  Future<void> listen() async {
    try {
      if (listening) {
        await speech.stop();
        stopped('Confira e corrija os campos antes de salvar.');
        return;
      }
      final available = await speech.initialize();
      if (!mounted) return;
      if (!available) {
        setState(
          () => voiceMessage =
              'Voz indisponível neste aparelho. Você pode digitar nos campos abaixo.',
        );
        return;
      }
      speech.statusListener = (status) {
        if (status == SpeechToText.doneStatus ||
            status == SpeechToText.notListeningStatus) {
          stopped(
            voice
                ? 'Confira e corrija os campos antes de salvar.'
                : 'Não entendi. Toque para falar de novo ou digite.',
          );
        }
      };
      speech.errorListener = (_) =>
          stopped('Não foi possível ouvir. Tente de novo ou digite.');
      setState(() {
        listening = true;
        voiceMessage =
            'Estou ouvindo… Diga o valor e com o que gastou, como “gastei 50 na padaria”.';
      });
      await speech.listen(
        listenOptions: SpeechListenOptions(
          localeId: 'pt_BR',
          listenFor: const Duration(seconds: 20),
          pauseFor: const Duration(seconds: 4),
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
          });
          if (r.finalResult) {
            stopped('Confira e corrija os campos antes de salvar.');
          }
        },
      );
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

  void resetForm() {
    description.clear();
    amount.clear();
    voice = false;
    editing = null;
    voiceMessage = null;
    date = defaultDate;
  }

  void startEditing(Spending s) {
    setState(() {
      editing = s;
      description.text = s.description;
      amount.text = editableMoney(s.amount);
      date = s.date;
      voice = s.voice;
      voiceMessage = null;
    });
    scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    final value = parseMoney(amount.text)!;
    if (voice &&
        editing == null &&
        !await confirm(
          context,
          'Confirmar gasto',
          '${description.text.trim()}: ${money(value)} em ${widget.item.name}?',
          action: 'Salvar',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    final month = widget.month;
    final spending = Spending(
      id: editing?.id ?? newId(),
      itemId: widget.item.id,
      description: description.text.trim(),
      amount: value,
      date: date,
      voice: voice,
    );
    final wasEditing = editing != null;
    if (wasEditing) {
      month.spending[month.spending.indexOf(editing!)] = spending;
    } else {
      month.spending.add(spending);
    }
    await widget.onSave();
    if (!mounted) return;
    setState(() {
      resetForm();
      busy = false;
    });
    notify(
      context,
      wasEditing ? 'Gasto atualizado.' : 'Gasto de ${money(value)} registrado.',
    );
  }

  Future<void> remove(Spending s) async {
    final month = widget.month;
    final index = month.spending.indexOf(s);
    month.spending.removeAt(index);
    if (editing == s) resetForm();
    await widget.onSave();
    if (!mounted) return;
    setState(() {});
    notify(
      context,
      'Gasto excluído.',
      action: SnackBarAction(
        label: 'Desfazer',
        onPressed: () async {
          month.spending.insert(min(index, month.spending.length), s);
          await widget.onSave();
          if (mounted) setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item, month = widget.month, c = context.colors;
    final used = month.spent(item.id), left = item.amount - used;
    final ratio = used / max(1, item.amount);
    final now = DateTime.now();
    final last = DateTime(month.date.year, month.date.month + 1, 0).day;
    final remaining = monthKey(now) == month.key
        ? last - now.day + 1
        : (month.date.isAfter(now) ? last : 0);
    final history = month.spending.where((s) => s.itemId == item.id).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final suggestions = history.map((s) => s.description).toSet().take(5);
    return Scaffold(
      appBar: AppBar(title: Text(item.name)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.all(20),
            children: [
              Panel(
                color: left < 0 ? c.danger : context.pocketFill(item.pocket),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${pocketName(item.pocket)} · ${monthTitle(month.date)}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      left < 0 ? 'Passou do limite em' : 'Ainda pode gastar',
                      style: const TextStyle(color: Colors.white),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        money(left.abs()),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: ratio.clamp(0, 1).toDouble(),
                      color: Colors.white,
                      backgroundColor: Colors.white24,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Gastou ${money(used)} de ${money(item.amount)} · ${(ratio * 100).round()}%',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              if (ratio >= .8 && left >= 0)
                Notice(
                  'Atenção: ${(ratio * 100).round()}% do limite já foi usado.',
                  icon: Icons.warning_amber_rounded,
                  warning: true,
                ),
              if (remaining > 0 && left > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 20),
                  child: Text(
                    'Restam $remaining dias neste mês, contando hoje. '
                    'Dá cerca de ${money(left ~/ remaining)} por dia.',
                    style: TextStyle(color: c.muted),
                  ),
                ),
              Panel(
                child: Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        editing == null ? 'Registrar um gasto' : 'Editar gasto',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (editing == null)
                        OutlinedButton.icon(
                          onPressed: listen,
                          style: listening
                              ? OutlinedButton.styleFrom(
                                  foregroundColor: c.danger,
                                  side: BorderSide(color: c.danger, width: 1.4),
                                )
                              : null,
                          icon: Icon(listening ? Icons.stop : Icons.mic_none),
                          label: Text(
                            listening ? 'Parar de ouvir' : 'Falar o gasto',
                          ),
                        ),
                      if (voiceMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            voiceMessage!,
                            style: TextStyle(color: c.muted, fontSize: 14),
                          ),
                        ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: description,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Com o quê?',
                          hintText: 'Ex.: mercado',
                        ),
                        validator: (s) => s == null || s.trim().isEmpty
                            ? 'Informe com o que gastou'
                            : null,
                      ),
                      if (suggestions.isNotEmpty && editing == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              for (final label in suggestions)
                                ActionChip(
                                  label: Text(label),
                                  onPressed: () =>
                                      setState(() => description.text = label),
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: amount,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: moneyInput,
                        decoration: const InputDecoration(
                          labelText: 'Valor',
                          prefixText: 'R\$ ',
                        ),
                        validator: positiveMoney,
                        onFieldSubmitted: (_) => submit(),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
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
                          label: Text(
                            'Dia ${DateFormat('dd/MM/yyyy').format(date)}',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: busy ? null : submit,
                        child: Text(
                          editing == null ? 'Salvar gasto' : 'Salvar alteração',
                        ),
                      ),
                      if (editing != null)
                        TextButton(
                          onPressed: () => setState(resetForm),
                          child: const Text('Cancelar edição'),
                        ),
                    ],
                  ),
                ),
              ),
              Heading(
                'Gastos registrados',
                subtitle: history.isEmpty
                    ? null
                    : '${history.length} ${history.length == 1 ? 'lançamento' : 'lançamentos'} · toque para editar',
                small: true,
              ),
              if (history.isEmpty)
                Panel(
                  child: Text(
                    'Nenhum gasto registrado nesta categoria ainda.',
                    style: TextStyle(color: c.muted),
                  ),
                ),
              if (history.isNotEmpty)
                Panel(
                  padding: 8,
                  child: Column(
                    children: [
                      for (final s in history) ...[
                        if (s != history.first) const Divider(indent: 64),
                        ListTile(
                          selected: s == editing,
                          onTap: () => startEditing(s),
                          leading: CircleAvatar(
                            backgroundColor: context.pocketTint(item.pocket),
                            foregroundColor: context.pocketColor(item.pocket),
                            child: Text(
                              DateFormat('dd').format(s.date),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          title: Text(
                            s.description,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${DateFormat("d 'de' MMM", 'pt_BR').format(s.date)}${s.voice ? ' · por voz' : ''}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                money(s.amount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Excluir gasto',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => remove(s),
                              ),
                            ],
                          ),
                        ),
                      ],
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
