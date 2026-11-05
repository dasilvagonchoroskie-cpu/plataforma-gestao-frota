// Combinado de pagamento (pedido de 05/11/2026): comissão, fixo ou fixo + %;
// a base é o frete cheio ou o que caiu na conta, com ou sem o pedágio; frete
// por tonelada ou cheio (valor fechado). Números do teste do Jorge (outubro).
import 'dart:io';
import 'dart:typed_data';

import 'package:nucleo/nucleo.dart';
import 'package:test/test.dart';

FontesPdf fontes() {
  ByteData ler(String nome) => ByteData.sublistView(File('lib/fontes/$nome').readAsBytesSync());
  final a = FontesPdf.arquivos;
  return FontesPdf.deBytes(ler(a[0]), ler(a[1]), ler(a[2]), ler(a[3]));
}

/// Jataí–Guarujá do Jorge: 40,4 t a R$ 385, descarregou 40,18 t, pedágio R$ 1.146 no cartão.
Frete jataiGuaruja({bool bruto = true, bool pedagio = true}) => Frete(
      id: 'f1', motoristaId: 'm1', caminhaoId: 'c1', origem: 'Jataí', destino: 'Guarujá',
      dataCarga: DateTime(2026, 10, 23), pesoCargaKg: 40400, valorToneladaCentavos: 38500, pesoDescargaKg: 40180,
      adiantamentoCentavos: 622160, saldoCentavos: 933240, pedagioCentavos: 114600, percentualComissao: 13,
      comissaoSobreBruto: bruto, comissaoComPedagio: pedagio,
    );

/// Santos–Goiânia: 35 t, sem valor da tonelada, R$ 5.000 na conta.
Frete santosGoiania({bool cheio = false}) => Frete(
      id: 'f2', motoristaId: 'm1', caminhaoId: 'c1', origem: 'Santos', destino: 'Goiânia',
      dataCarga: DateTime(2026, 10, 23), pesoCargaKg: 35000, adiantamentoCentavos: 350000, saldoCentavos: 150000,
      percentualComissao: 13, freteCheio: cheio, valorFreteCheioCentavos: cheio ? 500000 : 0, comissaoSobreBruto: cheio,
    );

void main() {
  test('"Frete + pedágio" agora soma o pedágio de verdade (era o erro do PDF do Jorge)', () {
    expect(reais(jataiGuaruja(pedagio: false).minhaParteCentavos), r'R$ 2.011,01', reason: 'o que o PDF mostrava');
    final f = jataiGuaruja();
    expect(reais(f.baseComissaoCentavos), r'R$ 16.615,30');
    expect(reais(f.minhaParteCentavos), r'R$ 2.159,99');
    expect(f.explicacaoDaBase, 'frete cheio + pedágio');
    final naConta = jataiGuaruja(bruto: false);
    expect(reais(naConta.baseComissaoCentavos), r'R$ 16.700,00', reason: 'o que caiu na conta + pedágio');
    expect(naConta.explicacaoDaBase, 'o que caiu na conta + pedágio');
  });

  test('frete gravado antes da mudança: "Frete + pedágio" vira com pedágio', () {
    final antigo = jataiGuaruja().paraMapa()..remove('comissao_com_pedagio');
    expect(Frete.deMapa(antigo).comissaoComPedagio, isTrue);
    final novo = jataiGuaruja(pedagio: false).paraMapa();
    expect(Frete.deMapa(novo).comissaoComPedagio, isFalse);
    expect(Frete.deMapa(santosGoiania(cheio: true).paraMapa()).valorFreteCheioCentavos, 500000);
  });

  test('frete cheio: o valor fechado é o contratado e a base do frete cheio', () {
    final f = santosGoiania(cheio: true);
    expect(f.valorContratadoCentavos, 500000);
    expect(f.baseComissaoCentavos, 500000);
    expect(f.explicacaoDaBase, 'frete cheio');
  });

  test('frete contratado não fica menor que o que caiu na conta', () {
    final r = calcularResumo(fretes: [jataiGuaruja(), santosGoiania()], abastecimentos: const [], gastos: const [], vales: const []);
    expect(reais(r.totalFretes), r'R$ 20.554,00');
    expect(reais(r.totalContratado), r'R$ 20.554,00', reason: 'antes mostrava R\$ 15.554,00');
    expect(r.totalDescontoDoFrete, 0);
  });

  test('salário fixo: mês fechado inteiro, pedaço de mês pelos dias', () {
    expect(salarioFixoNoPeriodo(300000, calcularPeriodo(TipoPeriodo.escolher, inicio: DateTime(2026, 10, 1), fim: DateTime(2026, 10, 31))!),
        300000);
    expect(salarioFixoNoPeriodo(300000, calcularPeriodo(TipoPeriodo.escolher, inicio: DateTime(2026, 11, 10), fim: DateTime(2026, 11, 25))!),
        closeTo(300000 * 16 / 30, 0.001));
    expect(salarioFixoNoPeriodo(310000, calcularPeriodo(TipoPeriodo.escolher, inicio: DateTime(2026, 10, 25), fim: DateTime(2026, 11, 5))!),
        closeTo(310000 * 7 / 31 + 310000 * 5 / 30, 0.001));
    expect(salarioFixoNoPeriodo(0, calcularPeriodo(TipoPeriodo.mesAtual)!), 0);
  });

  test('como o motorista ganha: comissão, fixo ou fixo + %', () {
    expect(FormaDeGanhar.de(0, 13), FormaDeGanhar.comissao);
    expect(FormaDeGanhar.de(300000, 0), FormaDeGanhar.fixo);
    expect(FormaDeGanhar.de(300000, 3), FormaDeGanhar.fixoMaisComissao);
  });

  test('combinado: padrão da empresa com exceção do motorista', () {
    final empresa = ConfiguracaoEmpresa.deMapa({
      'percentual_comissao_padrao': 13, 'comissao_sobre_bruto_padrao': true, 'comissao_com_pedagio_padrao': false,
      'salario_fixo_centavos': 0,
    });
    final jorge = empresa.doMotorista({'percentual_comissao': 3, 'salario_fixo_centavos': 300000, 'comissao_sobre_bruto': null});
    expect(jorge.percentualComissaoPadrao, 3);
    expect(jorge.salarioFixoCentavos, 300000);
    expect(jorge.comissaoSobreBrutoPadrao, isTrue, reason: 'segue a empresa');
    expect(jorge.comissaoComPedagioPadrao, isFalse);
    expect(jorge.formaDeGanhar, FormaDeGanhar.fixoMaisComissao);
    expect(empresa.doMotorista(null).percentualComissaoPadrao, 13);
    expect(ConfiguracaoEmpresa.deMapa({'comissao_sobre_bruto_padrao': true}).comissaoComPedagioPadrao, isTrue,
        reason: 'empresa gravada antes da mudança');
  });

  test('fixo + %: o fixo entra no líquido e sai da conta do caminhão', () {
    final f = jataiGuaruja().copyWith(percentualComissao: 3);
    final r = calcularResumo(fretes: [f], abastecimentos: const [], gastos: const [], vales: const [50000], salarioFixo: 300000);
    expect(r.salarioFixo, 300000);
    expect(r.liquido, closeTo(f.minhaParteCentavos + 300000 - 50000, 0.001));
    expect(r.sobraDoCaminhao, closeTo(r.totalFretes - f.minhaParteCentavos - 300000, 0.001));
  });

  test('montarDados põe o fixo proporcional; Baú e Sider não (vai no acerto)', () {
    final outubro = calcularPeriodo(TipoPeriodo.escolher, inicio: DateTime(2026, 10, 1), fim: DateTime(2026, 10, 31))!;
    DadosRelatorio dados({bool porViagem = false}) => montarDados(
          fretes: [jataiGuaruja()], abastecimentos: const [], vales: const [], gastos: const [], ajustes: const [],
          periodo: outubro, regras: const Regras(), salarioFixoMensalCentavos: 250000, porViagem: porViagem,
        );
    expect(dados().resultado.salarioFixo, 250000);
    expect(dados(porViagem: true).resultado.salarioFixo, 0);
    expect(csvFretes(dados().fretes), contains('frete cheio + pedágio'));
  });

  test('PDF com fixo, frete cheio e a base da comissão escrita', () async {
    final outubro = calcularPeriodo(TipoPeriodo.escolher, inicio: DateTime(2026, 10, 1), fim: DateTime(2026, 10, 31))!;
    final d = montarDados(
      fretes: [jataiGuaruja(), santosGoiania(cheio: true)], abastecimentos: const [], vales: const [], gastos: const [],
      ajustes: const [], periodo: outubro, regras: const Regras(), salarioFixoMensalCentavos: 250000, motorista: 'Jorge',
    );
    final bytes = await gerarPdf(d, fontes(), agora: DateTime(2026, 11, 5, 20));
    expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
    Directory('build').createSync(recursive: true);
    File('build/exemplo_combinado.pdf').writeAsBytesSync(bytes);
  });
}
