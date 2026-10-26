import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../domain/finance.dart';

const businessColor = Color(0xFF286747);
const familyColor = Color(0xFF285E99);
const inkColor = Color(0xFF202E26);
const fixedColor = Color(0xFFB74636);
const variableColor = Color(0xFF9B6800);
Color pocketColor(Pocket p) =>
    p == Pocket.business ? businessColor : familyColor;
String money(int cents) =>
    NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(cents / 100);
String editableMoney(int cents) =>
    (cents / 100).toStringAsFixed(2).replaceAll('.', ',');
String monthTitle(DateTime d) => DateFormat('MMMM yyyy', 'pt_BR').format(d);

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.color, this.padding = 20});
  final Widget child;
  final Color? color;
  final double padding;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Material(
      color: color ?? Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE0E6DD)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: EdgeInsets.all(padding), child: child),
    ),
  );
}

class Heading extends StatelessWidget {
  const Heading(this.title, {super.key, this.subtitle, this.action});
  final String title;
  final String? subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(subtitle!),
          ),
        if (action != null)
          Padding(padding: const EdgeInsets.only(top: 12), child: action!),
      ],
    ),
  );
}

class Summary extends StatelessWidget {
  const Summary({
    super.key,
    required this.income,
    required this.costs,
    required this.color,
  });
  final int income, costs;
  final Color color;
  @override
  Widget build(BuildContext context) => Panel(
    color: color,
    child: Wrap(
      spacing: 36,
      runSpacing: 20,
      children: [
        for (final v in [
          ('Entradas', income),
          ('Gastos', costs),
          (income >= costs ? 'Sobrou' : 'Faltou', (income - costs).abs()),
        ])
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(v.$1, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 4),
              Text(
                money(v.$2),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
      ],
    ),
  );
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    ) ??
    false;

String? positiveMoney(String? v) =>
    (parseMoney(v ?? '') ?? 0) <= 0 ? 'Informe um valor maior que zero' : null;
String? nonNegativeMoney(String? v) =>
    parseMoney(v ?? '') == null ? 'Informe um valor válido, como 150,50' : null;
