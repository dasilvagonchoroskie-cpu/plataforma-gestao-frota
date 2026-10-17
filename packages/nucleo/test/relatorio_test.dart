import 'dart:io';
import 'dart:typed_data';

import 'package:nucleo/nucleo.dart';
import 'package:test/test.dart';

FontesPdf fontes() {
  ByteData ler(String nome) => ByteData.sublistView(File('lib/fontes/$nome').readAsBytesSync());
  final a = FontesPdf.arquivos;
  return FontesPdf.deBytes(ler(a[0]), ler(a[1]), ler(a[2]), ler(a[3]));
}

DadosRelatorio exemplo({bool doisCaminhoes = false}) {
  final fretes = [
    Frete(
      id: 'f1', motoristaId: 'm1', caminhaoId: 'c1', origem: 'Goiatuba', destino: 'Santos', embarcador: 'Cerealista',
      dataCarga: DateTime(2026, 10, 2), pesoCargaKg: 37000, valorToneladaCentavos: 18500,
      adiantamentoCentavos: 480000, saldoCentavos: 195000, percentualComissao: 13, pesoDescargaKg: 36880,
      descontoQuebraCentavos: 2600, pedagioCentavos: 34000,
    ),
    Frete(
      id: 'f2', motoristaId: 'm1', caminhaoId: doisCaminhoes ? 'c2' : 'c1', origem: 'Santos', destino: 'Rio Verde',
      dataCarga: DateTime(2026, 10, 9), pesoCargaKg: 32000, valorToneladaCentavos: 16000,
      adiantamentoCentavos: 350000, percentualComissao: 13, camposAjustados: const ['adiantamento_centavos'],
    ),
  ];
  final abast = [
    Abastecimento(id: 'a0', motoristaId: 'm1', caminhaoId: 'c1', data: DateTime(2026, 10, 1), kmOdometro: 412000, pontoDePartida: true),
    Abastecimento(id: 'a1', motoristaId: 'm1', caminhaoId: 'c1', data: DateTime(2026, 10, 3), kmOdometro: 412900,
        litros: 350.5, valorCentavos: 210300, cidade: 'Rio Verde', posto: 'Posto Trevo'),
    Abastecimento(id: 'a2', motoristaId: 'm1', caminhaoId: 'c1', data: DateTime(2026, 10, 5), kmOdometro: 413800,
        litros: 340, valorCentavos: 204000, cidade: 'Uberlândia', posto: 'Graal'),
  ];
  final gastos = [
    Gasto(id: 'g1', motoristaId: 'm1', caminhaoId: 'c1', data: DateTime(2026, 10, 4), categoriaId: 'x',
        categoriaNome: 'Borracharia', valorCentavos: 8000),
  ];
  final vales = [Vale(id: 'v1', motoristaId: 'm1', data: DateTime(2026, 10, 3), valorCentavos: 50000)];
  final ajustes = [
    AjusteKm(id: 'k1', motoristaId: 'm1', caminhaoId: 'c1', quando: DateTime(2026, 10, 1, 8, 30), kmAnterior: 411000,
        kmNovo: 412000, motivo: 'Painel conferido'),
  ];
  return montarDados(
    fretes: fretes,
    abastecimentos: abast,
    vales: vales,
    gastos: gastos,
    ajustes: ajustes,
    periodo: calcularPeriodo(TipoPeriodo.mesAtual, agora: DateTime(2026, 10, 15))!,
    regras: const Regras(),
    motorista: 'João da Silva',
    placa: doisCaminhoes ? 'Todos' : 'ABC1D23',
    empresa: 'Transportes Goiatuba',
    placasPorCaminhao: const {'c1': 'ABC1D23', 'c2': 'DEF4567'},
  );
}

void main() {
  test('gera o PDF completo com acentos e símbolos', () async {
    final d = exemplo();
    final bytes = await gerarPdf(d, fontes(), agora: DateTime(2026, 10, 15, 10, 30));
    expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
    expect(bytes.length, greaterThan(20000));
    Directory('build').createSync(recursive: true);
    File('build/exemplo_relatorio.pdf').writeAsBytesSync(bytes);
    expect(nomeDoArquivoPdf(d), 'Frota_Joao_ABC1D23_completo_01-10-2026_a_31-10-2026.pdf');
  });

  test('gera todos os tipos de relatório, com um e com vários caminhões', () async {
    final f = fontes();
    for (final varios in [false, true]) {
      final base = exemplo(doisCaminhoes: varios);
      expect(base.variosCaminhoes, varios);
      for (final c in ConteudoRelatorio.values) {
        final d = DadosRelatorio(
          periodo: base.periodo, conteudo: c, fretes: base.fretes, abastecimentos: base.abastecimentos,
          abastecimentosCompletos: base.abastecimentosCompletos, vales: base.vales, gastos: base.gastos,
          ajustes: base.ajustes, resultado: base.resultado, regras: base.regras, motorista: base.motorista,
          placa: base.placa, empresa: base.empresa, placasPorCaminhao: base.placasPorCaminhao,
        );
        final bytes = await gerarPdf(d, f);
        expect(bytes.length, greaterThan(5000), reason: '$c varios=$varios');
      }
    }
  });

  test('acerto da viagem', () async {
    final base = exemplo();
    final d = montarDadosDaViagem(
      frete: base.fretes.first,
      fretes: base.fretes,
      abastecimentos: base.abastecimentosCompletos,
      vales: base.vales,
      gastos: base.gastos,
      ajustes: base.ajustes,
      regras: const Regras(),
      motorista: 'João da Silva',
      placa: 'ABC1D23',
      empresa: 'Transportes Goiatuba',
      agora: DateTime(2026, 10, 15),
    );
    expect(d.ehViagem, isTrue);
    expect(d.resultado.totalFretes, 675000);
    final bytes = await gerarPdf(d, fontes());
    File('build/exemplo_viagem.pdf').writeAsBytesSync(bytes);
    expect(nomeDoArquivoPdf(d), startsWith('Frota_Joao_ABC1D23_viagem_Goiatuba-Santos_'));
  });

  test('planilhas CSV dos lançamentos', () {
    final d = exemplo();
    final fretes = csvFretes(d.fretes, motoristas: const {'m1': 'João'}, placas: d.placasPorCaminhao);
    expect(fretes, contains('02/10/2026;João;ABC1D23;Goiatuba;Santos;Cerealista;37000;36880;185,00;6845,00;4800,00;1950,00;6750,00'));
    expect(fretes, contains('adiantamento'));
    final diesel = csvAbastecimentos(d.abastecimentos, d.abastecimentosCompletos, placas: d.placasPorCaminhao);
    expect(diesel, contains('03/10/2026;;ABC1D23;Rio Verde;Posto Trevo;412900;350,50;2103,00'));
    expect(csvGastos(d.gastos), contains('Borracharia;80,00'));
    expect(csvVales(d.vales), contains('03/10/2026;;500,00'));
  });
}
