import 'package:nucleo/nucleo.dart';
import 'package:test/test.dart';

void main() {
  test('regra de senha: 8 a 72 caracteres, com letras e números', () {
    expect(senhaAceita('abc12345'), isTrue);
    expect(senhaAceita('SENHA2026'), isTrue);
    expect(senhaAceita('abcdefgh'), isFalse, reason: 'sem número');
    expect(senhaAceita('12345678'), isFalse, reason: 'sem letra');
    expect(senhaAceita('ab1'), isFalse, reason: 'curta');
    expect(senhaAceita('a1' * 37), isFalse, reason: 'mais de 72');
  });
}
