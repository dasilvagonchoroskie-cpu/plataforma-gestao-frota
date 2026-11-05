// Forma de pagamento do gasto (pedido de 23/10/2026): o que o motorista paga
// em dinheiro sai do vale; o que vai na nota a empresa paga direto. A conta é
// a mesma do servidor (para_receber_acerto).
import 'dart:io';
import 'dart:typed_data';

import 'package:nucleo/nucleo.dart';
import 'package:test/test.dart';

FontesPdf fontes() {
  ByteData ler(String nome) => ByteData.sublistView(File('lib/fontes/$nome').readAsBytesSync());
  final a = FontesPdf.arquivos;
  return FontesPdf.deBytes(ler(a[0]), ler(a[1]), ler(a[2]), ler(a[3]));
}

Frete frete() => Frete(
      id: 'f1', motoristaId: 'm1', caminhaoId: 'c1', origem: 'Jataí', destino: 'Santos',
      dataCarga: DateTime(2026, 10, 5), pesoCargaKg: 37000, valorToneladaCentavos: 41800,
      adiantamentoCentavos: 1000000, saldoCentavos: 546900, percentualComissao: 13,
    );

Gasto gasto(String id, int valor, FormaPagamento forma) => Gasto(
      id: id, motoristaId: 'm1', caminhaoId: 'c1', data: DateTime(2026, 10, 6), categoriaId: 'cat',
      categoriaNome: id == 'g1' ? 'Pátio' : 'Lavagem', valorCentavos: valor, formaPagamento: forma,
    );

void main() {
  test('gasto: forma de pagamento vai e volta do banco; gasto antigo conta como nota', () {
    final g = gasto('g1', 12000, FormaPagamento.dinheiro);
    expect(g.paraMapa()['forma_pagamento'], 'dinheiro');
    expect(Gasto.deMapa(g.paraMapa()).emDinheiro, isTrue);
    final antigo = Map<String, Object?>.from(g.paraMapa())..remove('forma_pagamento');
    expect(Gasto.deMapa(antigo).formaPagamento, FormaPagamento.nota);
    expect(g.copyWith(formaPagamento: FormaPagamento.nota).emDinheiro, isFalse);
    expect(FormaPagamento.dinheiro.rotulo, 'Paguei em dinheiro');
    expect(FormaPagamento.nota.rotulo, 'Assinei a nota');
  });

  test('empresa paga os gastos: o vale desconta e o que foi pago em dinheiro volta (exemplo do Evandro)', () {
    // Vale de R$ 500 e pátio de R$ 120 pago em dinheiro: só R$ 380 saem da comissão.
    final r = calcularResumo(
      fretes: [frete()], abastecimentos: const [294000], gastos: const [12000, 8000],
      gastosDinheiro: const [12000], vales: const [50000],
    );
    expect(r.totalGastosDinheiro, 12000);
    expect(r.devolvidoDoVale, 12000);
    expect(r.descontoGastos, 0);
    expect(r.liquido, r.comissao - 50000 + 12000);
  });

  test('gastou mais do que o vale: a diferença volta para o motorista', () {
    final r = calcularResumo(
      fretes: [frete()], abastecimentos: const [], gastos: const [30000],
      gastosDinheiro: const [30000], vales: const [10000],
    );
    expect(r.liquido, r.comissao + 20000);
  });

  test('gastos por conta do motorista: desconta só o que foi na nota (o dinheiro já saiu do vale)', () {
    final r = calcularResumo(
      fretes: [frete()], abastecimentos: const [40000], gastos: const [12000, 8000],
      gastosDinheiro: const [12000], vales: const [50000],
      regras: const Regras(gastosDescontamDoLiquido: true),
    );
    expect(r.devolvidoDoVale, 0);
    expect(r.descontoGastos, 40000 + 8000);
    expect(r.liquido, r.comissao - 48000 - 50000);
  });

  test('vale que não desconta e gastos sem dinheiro: a conta é a de antes', () {
    final semVale = calcularResumo(
      fretes: [frete()], abastecimentos: const [], gastos: const [12000],
      gastosDinheiro: const [12000], vales: const [50000], regras: const Regras(valeDescontaDoLiquido: false),
    );
    expect(semVale.liquido, semVale.comissao);
    final tudoNota = calcularResumo(fretes: [frete()], abastecimentos: const [], gastos: const [12000], vales: const [50000]);
    expect(tudoNota.liquido, tudoNota.comissao - 50000);
  });

  test('montarDados separa os gastos pagos em dinheiro', () {
    final periodo = Periodo(DateTime(2026, 10), DateTime(2026, 11));
    final d = montarDados(
      fretes: [frete()], abastecimentos: const [],
      gastos: [gasto('g1', 12000, FormaPagamento.dinheiro), gasto('g2', 8000, FormaPagamento.nota)],
      vales: [Vale(id: 'v1', motoristaId: 'm1', data: DateTime(2026, 10, 3), valorCentavos: 50000)],
      ajustes: const [], periodo: periodo, regras: const Regras(),
    );
    expect(d.resultado.totalGastosDinheiro, 12000);
    expect(d.resultado.liquido, d.resultado.comissao - 38000);
    expect(csvGastos(d.gastos), contains('Pátio;120,00;Dinheiro'));
    expect(csvGastos(d.gastos), contains('Lavagem;80,00;Nota'));
  });

  test('acerto: a mesma conta do servidor, com a conta escrita', () {
    int conta(Regras r, {int dinheiro = 12000}) => calcularParaReceber(
          comissaoCentavos: 150000, descontos: const [], valesCentavos: 50000, dieselCentavos: 40000,
          gastosCentavos: 20000, gastosDinheiroCentavos: dinheiro, regras: r,
        );
    expect(conta(const Regras()), 150000 - 50000 + 12000);
    expect(conta(const Regras(gastosDescontamDoLiquido: true)), 150000 - 50000 - 40000 - 8000);
    expect(conta(const Regras(valeDescontaDoLiquido: false)), 150000);
    expect(conta(const Regras(), dinheiro: 0), 100000);
    final a = Acerto.deMapa({
      'id': 'a1', 'motorista_id': 'm1', 'periodo_inicio': '2026-10-01', 'periodo_fim': '2026-10-15',
      'comissao_centavos': 150000, 'vales_centavos': 50000, 'gastos_centavos': 20000, 'gastos_dinheiro_centavos': 12000,
      'desconta_vales': true, 'desconta_gastos': false, 'para_receber_centavos': 112000,
    });
    expect(a.gastosDinheiroCentavos, 12000);
    expect(contaDoAcerto(a), contains('mais gastos pagos em dinheiro R\$ 120,00'));
    expect(nomeDoCampo('forma_pagamento'), 'forma de pagamento');
  });

  test('PDF do período mostra os gastos pagos em dinheiro', () async {
    final periodo = Periodo(DateTime(2026, 10), DateTime(2026, 11));
    final d = montarDados(
      fretes: [frete()], abastecimentos: const [],
      gastos: [gasto('g1', 12000, FormaPagamento.dinheiro), gasto('g2', 8000, FormaPagamento.nota)],
      vales: [Vale(id: 'v1', motoristaId: 'm1', data: DateTime(2026, 10, 3), valorCentavos: 50000)],
      ajustes: const [], periodo: periodo, regras: const Regras(), motorista: 'João Batista',
    );
    final bytes = await gerarPdf(d, fontes(), agora: DateTime(2026, 10, 20, 9));
    expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
    Directory('build').createSync(recursive: true);
    File('build/exemplo_forma_pagamento.pdf').writeAsBytesSync(bytes);
  });
}
