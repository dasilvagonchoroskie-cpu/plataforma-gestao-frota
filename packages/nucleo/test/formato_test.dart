import 'package:nucleo/nucleo.dart';
import 'package:test/test.dart';

void main() {
  test('dinheiro no padrão brasileiro (centavos)', () {
    expect(dinheiro(123450), '1.234,50');
    expect(dinheiro(0), '0,00');
    expect(dinheiro(123456789.1), '1.234.567,89');
    expect(reais(-1200), '−R\$ 12,00');
    expect(reais(-0.1), 'R\$ 0,00');
    expect(semCasas(412300), '412.300');
    expect(toneladas(33040), '33,040');
    expect(percentualTexto(13), '13');
    expect(percentualTexto(12.5), '12,5');
  });

  test('datas no horário do celular', () {
    final dt = DateTime(2026, 10, 9, 14, 5);
    expect(dataTexto(dt), '09/10/2026');
    expect(dataHoraTexto(dt), '09/10/2026 às 14:05');
    expect(mesAno(DateTime(2026, 3)), 'março de 2026');
    expect(plural(1, 'frete', 'fretes'), '1 frete');
    expect(plural(3, 'frete', 'fretes'), '3 fretes');
  });

  test('ler o que foi digitado', () {
    expect(lerNumero('1.234,56'), 1234.56);
    expect(lerNumero('33.040'), 33040);
    expect(lerNumero('350,5'), 350.5);
    expect(lerNumero('12.5'), 12.5);
    expect(lerNumero('R\$ 10,00'), 10);
    expect(lerNumero(''), 0);
    expect(lerNumero('abc'), 0);
    expect(lerCentavos('1.234,56'), 123456);
    expect(lerCentavos('0,1'), 10);
    expect(textoDinheiro(0), '');
    expect(textoDecimal(13), '13');
    expect(textoDecimal(350.5, casas: 3), '350,5');
  });

  test('placa do caminhão', () {
    expect(normalizarPlaca('abc-1d23'), 'ABC1D23');
    expect(placaValida('ABC1D23'), isTrue);
    expect(placaValida('abc-1234'), isTrue);
    expect(placaValida('AB1234'), isFalse);
    expect(placaValida('1BC1D23'), isFalse);
    expect(placaTexto('ABC1234'), 'ABC-1234');
    expect(placaTexto('ABC1D23'), 'ABC1D23');
  });

  test('CPF: mesma conta do servidor', () {
    expect(cpfValido('529.982.247-25'), isTrue);
    expect(cpfValido('11144477735'), isTrue);
    expect(cpfValido('12345678900'), isFalse);
    expect(cpfValido('11111111111'), isFalse);
    expect(cpfValido('5299822472'), isFalse);
    expect(cpfTexto('52998224725'), '529.982.247-25');
    expect(cpfTexto('5299'), '529.9');
    expect(cpfMascarado('52998224725'), '***.982.247-**');
  });

  test('planilha CSV para Excel em português', () {
    final csv = gerarCsv(['Nome', 'Valor'], [
      ['Posto; Centro', '1.234,50'],
      ['Aspas "x"', null],
    ]);
    expect(csv.startsWith('﻿'), isTrue);
    final linhas = csv.substring(1).trim().split('\n');
    expect(linhas[0], 'Nome;Valor');
    expect(linhas[1], '"Posto; Centro";1.234,50');
    expect(linhas[2], '"Aspas ""x""";');
  });
}
