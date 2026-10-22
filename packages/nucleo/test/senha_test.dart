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

  test('formato do e-mail: algo@algo.algo, sem espaços', () {
    expect(emailValido('motorista@gmail.com'), isTrue);
    expect(emailValido('  Dono@Empresa.com.br '), isTrue);
    expect(emailValido('sem-arroba.com'), isFalse);
    expect(emailValido('a@b'), isFalse, reason: 'sem ponto no domínio');
    expect(emailValido('a b@c.com'), isFalse, reason: 'com espaço');
    expect(emailValido('${'a' * 250}@b.com'), isFalse, reason: 'mais de 254');
  });
}
