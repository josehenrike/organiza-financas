import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:organiza_financas/features/finance/presentation/finance_widgets.dart';

void main() {
  final formatter = MoneyInputFormatter();
  TextEditingValue value(String text) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );
  test('digitação, colagem e exclusão formatam centavos e milhares', () {
    var current = TextEditingValue.empty;
    for (final digit in '123456'.split('')) {
      current = formatter.formatEditUpdate(
        current,
        value(current.text + digit),
      );
    }
    expect(current.text, '1.234,56');
    expect(
      formatter.formatEditUpdate(current, value('R\$ 2.500,90')).text,
      '2.500,90',
    );
    expect(
      formatter.formatEditUpdate(current, value('1.234,5')).text,
      '123,45',
    );
    expect(
      formatter.formatEditUpdate(current, TextEditingValue.empty).text,
      '',
    );
  });
  test('edição no meio mantém cursor próximo do algarismo alterado', () {
    final result = formatter.formatEditUpdate(
      value('1.234,56'),
      const TextEditingValue(
        text: '1.294,56',
        selection: TextSelection.collapsed(offset: 4),
      ),
    );
    expect(result.text, '1.294,56');
    expect(result.selection.extentOffset, 4);
  });
}
