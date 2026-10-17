import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motorista/dados/armazenamento.dart';
import 'package:nucleo/nucleo.dart';

import 'apoio.dart';

/// Carrega as letras do app (Barlow e os ícones) para as imagens saírem reais.
Future<void> carregarFontes() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final manifesto = json.decode(await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
  for (final f in manifesto) {
    final familia = (f as Map<String, dynamic>)['family'] as String;
    final carregador = FontLoader(familia.replaceFirst(RegExp(r'^packages/[^/]+/'), ''));
    for (final fonte in f['fonts'] as List<dynamic>) {
      carregador.addFont(rootBundle.load((fonte as Map<String, dynamic>)['asset'] as String));
    }
    await carregador.load();
  }
}

DateTime dia(int d, {int mesesAtras = 0}) {
  final agora = DateTime.now();
  return DateTime(agora.year, agora.month - mesesAtras, d);
}

/// Celular de um motorista com um mês de lançamentos, parecido com o real.
Future<ArmazenamentoMemoria> celularComAmostra() async {
  final a = ArmazenamentoMemoria();
  await a.gravarEstado('situacao', jsonEncode(situacaoDe(motoristaA, nome: 'João Batista')));
  await a.gravarEstado('pronto', '1');
  await a.gravarRegistros('caminhoes', [
    const Caminhao(id: caminhao1, placa: 'RVG2C47', numeroFrota: '07', modelo: 'Scania R450').paraMapa(),
    const Caminhao(id: caminhao2, placa: 'DEF4567', numeroFrota: '12', modelo: 'Volvo FH 540').paraMapa(),
  ]);
  await a.gravarRegistros('categorias_gasto', [
    for (final n in ['Borracharia', 'Chapa', 'Lavagem', 'Manutenção', 'Pedágio', 'Alimentação'])
      CategoriaGasto(id: 'cat-$n', nome: n).paraMapa(),
  ]);
  await a.gravarRegistros('uso_caminhao', [
    UsoCaminhao(id: 'uso-1', motoristaId: motoristaA, caminhaoId: caminhao1, inicioEm: dia(1, mesesAtras: 2)).paraMapa(),
  ]);
  await a.gravarRegistros('fretes', [
    Frete(
      id: 'f1', motoristaId: motoristaA, caminhaoId: caminhao1, origem: 'Jataí (GO)', destino: 'Paranaguá (PR)',
      embarcador: 'Cerealista Cerrado', dataCarga: dia(3), pesoCargaKg: 37000, valorToneladaCentavos: 21000,
      adiantamentoCentavos: 540000, saldoCentavos: 225000, pedagioCentavos: 69000, percentualComissao: 13,
    ).paraMapa(),
    Frete(
      id: 'f2', motoristaId: motoristaA, caminhaoId: caminhao1, origem: 'Paranaguá (PR)', destino: 'Rio Verde (GO)',
      embarcador: 'Fertilizantes Sul', dataCarga: dia(8), pesoCargaKg: 32000, valorToneladaCentavos: 16500,
      adiantamentoCentavos: 380000, percentualComissao: 13, pesoDescargaKg: 31880, descontoQuebraCentavos: 2500,
    ).paraMapa(),
  ]);
  await a.gravarRegistros('abastecimentos', [
    Abastecimento(id: 'p0', motoristaId: motoristaA, caminhaoId: caminhao1, data: dia(1), kmOdometro: 412000, pontoDePartida: true).paraMapa(),
    Abastecimento(id: 'a1', motoristaId: motoristaA, caminhaoId: caminhao1, data: dia(4), kmOdometro: 412950,
        litros: 380, valorCentavos: 228000, cidade: 'Maringá', posto: 'Posto Trevo').paraMapa(),
    Abastecimento(id: 'a2', motoristaId: motoristaA, caminhaoId: caminhao1, data: dia(9), kmOdometro: 413900,
        litros: 365.5, valorCentavos: 219300, cidade: 'Campo Grande', posto: 'Graal').paraMapa(),
  ]);
  await a.gravarRegistros('gastos_viagem', [
    Gasto(id: 'g1', motoristaId: motoristaA, caminhaoId: caminhao1, data: dia(5), categoriaId: 'cat-Borracharia', valorCentavos: 8000).paraMapa(),
    Gasto(id: 'g2', motoristaId: motoristaA, caminhaoId: caminhao1, data: dia(8), categoriaId: 'cat-Chapa', valorCentavos: 25000).paraMapa(),
  ]);
  await a.gravarRegistros('vales', [
    Vale(id: 'v1', motoristaId: motoristaA, data: dia(4), valorCentavos: 50000, observacao: 'Adiantamento').paraMapa(),
  ]);
  await a.gravarRegistros('ajustes_gestor', [
    AjusteGestor(id: 'aj1', tabelaAlvo: 'fretes', registroId: 'f2', campo: 'adiantamento_centavos',
        valorNovo: 400000, motivo: 'Conferido no extrato', criadoEm: DateTime.now()).paraMapa(),
  ]);
  await a.enfileirar('gastos_viagem', 'g2', (await a.registro('gastos_viagem', 'g2'))!);
  return a;
}
