import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/finance.dart';

extension FinanceTheme on BuildContext {
  FinanceColors get colors => Theme.of(this).extension<FinanceColors>()!;
  Color pocketColor(Pocket p) =>
      p == Pocket.business ? colors.business : colors.family;
  Color pocketFill(Pocket p) =>
      p == Pocket.business ? colors.businessFill : colors.familyFill;
  Color pocketTint(Pocket p) =>
      p == Pocket.business ? colors.businessTint : colors.familyTint;
}

IconData pocketIcon(Pocket p) =>
    p == Pocket.business ? Icons.agriculture_outlined : Icons.home_outlined;

String money(int cents) =>
    NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(cents / 100);
String editableMoney(int cents) =>
    (cents / 100).toStringAsFixed(2).replaceAll('.', ',');
String monthTitle(DateTime d) {
  final text = DateFormat("MMMM 'de' yyyy", 'pt_BR').format(d);
  return text[0].toUpperCase() + text.substring(1);
}

/// Aceita apenas algarismos, ponto e vírgula em campos de dinheiro.
final moneyInput = [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))];

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.color,
    this.padding = 20,
    this.onTap,
  });
  final Widget child;
  final Color? color;
  final double padding;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Material(
      color: color ?? context.colors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: color == null
            ? BorderSide(color: context.colors.border)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: EdgeInsets.all(padding), child: child),
      ),
    ),
  );
}

class Heading extends StatelessWidget {
  const Heading(this.title, {super.key, this.subtitle, this.small = false});
  final String title;
  final String? subtitle;
  final bool small;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: small ? 12 : 20, top: small ? 8 : 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style:
              (small
                      ? Theme.of(context).textTheme.titleLarge
                      : Theme.of(context).textTheme.headlineMedium)
                  ?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              subtitle!,
              style: TextStyle(color: context.colors.muted),
            ),
          ),
      ],
    ),
  );
}

/// Título de cartão, com ícone e um valor opcional à direita.
/// Versão instalada, como "Versão 1.1.0 (2)". Fica vazio se não for possível
/// ler a versão.
class AppVersion extends StatelessWidget {
  const AppVersion({super.key, this.prefix = '', this.style});
  final String prefix;
  final TextStyle? style;
  static PackageInfo? _cached;
  static final _info = PackageInfo.fromPlatform().then((i) => _cached = i);
  @override
  Widget build(BuildContext context) => FutureBuilder<PackageInfo>(
    future: _info,
    initialData: _cached,
    builder: (context, snapshot) {
      final info = snapshot.data;
      if (info == null) return const SizedBox.shrink();
      return Text(
        '${prefix}Versão ${info.version} (${info.buildNumber})',
        textAlign: TextAlign.center,
        style: style ?? TextStyle(fontSize: 12, color: context.colors.muted),
      );
    },
  );
}

/// Ícone "i" que explica uma funcionalidade ao ser tocado.
class InfoButton extends StatelessWidget {
  const InfoButton({super.key, required this.title, required this.message});
  final String title, message;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Saiba mais: $title',
    icon: const Icon(Icons.info_outline),
    color: context.colors.muted,
    onPressed: () => showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        // Textos longos rolam em telas pequenas ou com fonte ampliada.
        scrollable: true,
        icon: const Icon(Icons.info_outline),
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Entendi'),
          ),
        ],
      ),
    ),
  );
}

class CardTitle extends StatelessWidget {
  const CardTitle(
    this.title, {
    super.key,
    required this.icon,
    this.color,
    this.trailing,
    this.info,
  });
  final String title;
  final IconData icon;
  final Color? color;
  final String? trailing;

  /// Explicação mostrada ao tocar no ícone "i" ao lado do título.
  final String? info;
  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colors.business;
    final style = TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.w800,
      color: c,
    );
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: c.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: c, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: style)),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Text(trailing!, style: style),
        ],
        if (info != null) InfoButton(title: title, message: info!),
      ],
    );
  }
}

class Summary extends StatelessWidget {
  const Summary({
    super.key,
    required this.income,
    required this.costs,
    required this.color,
    this.forecast = true,
  });
  final int income, costs;
  final Color color;

  /// Previsão ("deve sobrar") ou valores já realizados ("sobrou").
  final bool forecast;
  @override
  Widget build(BuildContext context) {
    final result = income - costs;
    Widget stat(String title, int value, IconData icon) => Expanded(
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    money(value),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return Panel(
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            forecast
                ? (result >= 0 ? 'Deve sobrar no mês' : 'Deve faltar no mês')
                : (result >= 0 ? 'Sobrou no mês' : 'Faltou no mês'),
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${result < 0 ? '−' : ''}${money(result.abs())}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white24),
          const SizedBox(height: 16),
          Row(
            children: [
              stat('Entradas', income, Icons.south_west),
              const SizedBox(width: 12),
              stat('Gastos', costs, Icons.north_east),
            ],
          ),
        ],
      ),
    );
  }
}

/// Barra de progresso arredondada com a cor de alerta a partir de 80%.
class Meter extends StatelessWidget {
  const Meter({
    super.key,
    required this.ratio,
    required this.color,
    this.height = 8,
    this.warn = true,
    this.background,
  });
  final double ratio;
  final Color color;
  final double height;
  final bool warn;
  final Color? background;
  @override
  Widget build(BuildContext context) => LinearProgressIndicator(
    value: ratio.clamp(0, 1).toDouble(),
    color: warn && ratio >= .8 ? context.colors.danger : color,
    backgroundColor: background ?? context.colors.track,
    minHeight: height,
    borderRadius: BorderRadius.circular(height),
  );
}

/// Gráfico de colunas com linha do zero: verde quando sobra, vermelho quando
/// falta. A última coluna (mês exibido) fica em destaque.
class BalanceChart extends StatelessWidget {
  const BalanceChart({super.key, required this.bars});
  final List<(String label, int value)> bars;
  static const _area = 140.0;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final maxPos = bars.fold(0, (v, b) => max(v, b.$2));
    final maxNeg = bars.fold(0, (v, b) => max(v, -b.$2));
    final total = max(1, maxPos + maxNeg);
    final posArea = maxNeg == 0 ? _area : _area * maxPos / total;
    final compact = NumberFormat.compact(locale: 'pt_BR');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (i, bar) in bars.indexed)
          Expanded(
            child: Semantics(
              label:
                  '${bar.$1}: ${bar.$2 >= 0 ? 'sobrou' : 'faltou'} '
                  '${money(bar.$2.abs())}',
              excludeSemantics: true,
              child: Opacity(
                opacity: i == bars.length - 1 ? 1 : .55,
                child: Column(
                  children: [
                    Text(
                      '${bar.$2 < 0 ? '−' : ''}${compact.format(bar.$2.abs() / 100)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: bar.$2 >= 0 ? c.business : c.danger,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _bar(
                      context,
                      posArea,
                      bar.$2 > 0 ? _area * bar.$2 / total : 0,
                      top: true,
                    ),
                    Container(height: 1.5, color: c.border),
                    _bar(
                      context,
                      _area - posArea,
                      bar.$2 < 0 ? _area * -bar.$2 / total : 0,
                      top: false,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      bar.$1,
                      style: TextStyle(
                        fontSize: 13,
                        color: c.muted,
                        fontWeight: i == bars.length - 1
                            ? FontWeight.w800
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _bar(
    BuildContext context,
    double space,
    double height, {
    required bool top,
  }) {
    const r = Radius.circular(6);
    return SizedBox(
      height: space,
      child: Align(
        alignment: top ? Alignment.bottomCenter : Alignment.topCenter,
        child: FractionallySizedBox(
          widthFactor: .55,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: top ? context.colors.business : context.colors.danger,
              borderRadius: top
                  ? const BorderRadius.vertical(top: r)
                  : const BorderRadius.vertical(bottom: r),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mostra dois cartões lado a lado em telas largas e empilhados no celular.
class Pair extends StatelessWidget {
  const Pair(this.first, this.second, {super.key});
  final Widget first, second;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 1000) {
      return Column(children: [first, second]);
    }
    // Mesma altura nos dois cartões, para alinhar as bordas.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: first),
          const SizedBox(width: 16),
          Expanded(child: second),
        ],
      ),
    );
  }
}

/// Faixa de aviso ou dica com ícone.
class Notice extends StatelessWidget {
  const Notice(
    this.text, {
    super.key,
    this.icon = Icons.info_outline,
    this.warning = false,
    this.action,
  });
  final String text;
  final IconData icon;
  final bool warning;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = warning ? c.onWarningSurface : null;
    return Panel(
      color: warning ? c.warningSurface : c.businessTint,
      padding: 16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg ?? c.business, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: TextStyle(color: fg)),
                if (action != null) action!,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String message, {
  String action = 'Confirmar',
  bool destructive = false,
}) async =>
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
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: c.colors.danger,
                    foregroundColor: Theme.of(c).colorScheme.surface,
                  )
                : null,
            onPressed: () => Navigator.pop(c, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

void notify(BuildContext context, String message, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), action: action));
}

String? positiveMoney(String? v) =>
    (parseMoney(v ?? '') ?? 0) <= 0 ? 'Informe um valor maior que zero' : null;
String? nonNegativeMoney(String? v) =>
    parseMoney(v ?? '') == null ? 'Informe um valor válido, como 150,50' : null;
