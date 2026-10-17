// Testes das regras portadas do Meu Frete. Os números são os mesmos dos
// testes do Meu Frete (test/regras_test.dart); lá o dinheiro está em reais e
// aqui em centavos, por isso os valores aparecem multiplicados por 100.
import 'package:nucleo/nucleo.dart';
import 'package:test/test.dart';

DateTime d(int ano, int mes, int dia) => DateTime(ano, mes, dia);

Frete frete({
  String id = 'f',
  String motorista = 'm1',
  String caminhao = 'c1',
  String origem = 'A',
  String destino = 'B',
  DateTime? dataCarga,
  double pesoKg = 0,
  int valorTonelada = 0,
  int adiantamento = 0,
  int saldo = 0,
  double percentual = 13,
  bool sobreBruto = true,
  int pedagio = 0,
  double descarga = 0,
  int descontoQuebra = 0,
  String embarcador = '',
}) =>
    Frete(
      id: id,
      motoristaId: motorista,
      caminhaoId: caminhao,
      origem: origem,
      destino: destino,
      embarcador: embarcador,
      dataCarga: dataCarga ?? DateTime.utc(1970),
      pesoCargaKg: pesoKg,
      valorToneladaCentavos: valorTonelada,
      adiantamentoCentavos: adiantamento,
      saldoCentavos: saldo,
      percentualComissao: percentual,
      comissaoSobreBruto: sobreBruto,
      pedagioCentavos: pedagio,
      pesoDescargaKg: descarga,
      descontoQuebraCentavos: descontoQuebra,
    );

Abastecimento abast(String id, double km,
        {double litros = 0, bool cheio = true, bool partida = false, String caminhao = 'c1', int valor = 0, DateTime? data}) =>
    Abastecimento(
      id: id,
      motoristaId: 'm1',
      caminhaoId: caminhao,
      data: data ?? DateTime.utc(1970),
      kmOdometro: km,
      litros: litros,
      tanqueCheio: cheio,
      pontoDePartida: partida,
      valorCentavos: valor,
    );

void main() {
  group('Frete', () {
    test('frete real, contratado, comissão e quebra (igual ao Meu Frete)', () {
      final f = frete(
        pesoKg: 37000,
        valorTonelada: 18500,
        adiantamento: 480000,
        saldo: 195000,
        percentual: 13,
        sobreBruto: false,
        descarga: 36880,
        descontoQuebra: 2600,
      );
      expect(f.freteRealCentavos, 675000);
      expect(f.valorContratadoCentavos, closeTo(684500, 0.001));
      expect(f.baseComissaoCentavos, 675000);
      expect(f.minhaParteCentavos, closeTo(87750, 0.001));
      expect(f.quebraKg, 120);
      expect(f.valorQuebraIntegralCentavos, closeTo(2220, 0.001));
      expect(f.freteSemQuebraCentavos, 677600);
      expect(f.aguardandoSaldo, isFalse);
      expect(reais(f.minhaParteCentavos), r'R$ 877,50');
    });

    test('comissão sobre o bruto usa o peso da descarga quando tem', () {
      final f = frete(
        pesoKg: 30000,
        valorTonelada: 10000,
        adiantamento: 200000,
        saldo: 50000,
        percentual: 10,
        sobreBruto: true,
        descarga: 29000,
      );
      expect(f.baseComissaoCentavos, closeTo(290000, 0.001));
      expect(f.minhaParteCentavos, closeTo(29000, 0.001));
    });

    test('sem descarga não tem quebra', () {
      final f = frete(pesoKg: 30000);
      expect(f.quebraKg, isNull);
      expect(f.valorQuebraIntegralCentavos, 0);
    });

    test('mapa ida e volta com os nomes das colunas do banco', () {
      final f = frete(id: 'x7', embarcador: 'Cerealista', pesoKg: 1, sobreBruto: false, dataCarga: DateTime.utc(2026, 10, 5, 3));
      final g = Frete.deMapa(f.paraMapa());
      expect(g.id, 'x7');
      expect(g.embarcador, 'Cerealista');
      expect(g.comissaoSobreBruto, isFalse);
      expect(g.dataCarga, DateTime.utc(2026, 10, 5, 3));
      expect(f.paraMapa()['data_carga'], '2026-10-05T03:00:00.000Z');
    });

    test('lê os números que o banco devolve como texto', () {
      final g = Frete.deMapa({
        'id': 'a',
        'motorista_id': 'm',
        'caminhao_id': 'c',
        'origem': 'A',
        'destino': 'B',
        'data_carga': '2026-10-05T03:00:00+00:00',
        'peso_carga_kg': '37000.00',
        'percentual_comissao': '13.0000',
        'saldo_centavos': 195000,
        'campos_ajustados': ['saldo_centavos'],
      });
      expect(g.pesoCargaKg, 37000);
      expect(g.percentualComissao, 13);
      expect(g.ajustado, isTrue);
    });
  });

  group('Média do diesel', () {
    final salvas = [
      abast('1', 1000, partida: true),
      abast('2', 1500, litros: 200, cheio: false),
      abast('3', 2000, litros: 150),
    ];

    test('soma os litros desde o último tanque cheio', () {
      final m = mediaDaLinha(salvas, salvas[2]);
      expect(m.kmRodados, 1000);
      expect(m.litrosContados, 350);
      expect(m.media, closeTo(1000 / 350, 1e-9));
      expect(m.abastecidasContadas, 2);
      expect(m.kmReferencia, 1000);
    });

    test('tanque não completado não tem média', () {
      final m = mediaDaLinha(salvas, salvas[1]);
      expect(m.media, isNull);
      expect(m.motivo, contains('não foi completado'));
    });

    test('primeira cheia não tem média', () {
      final m = calcularMedia(const [], km: 500, litros: 100, tanqueCheio: true);
      expect(m.media, isNull);
      expect(m.motivo, contains('primeira'));
    });

    test('nova abastecida conta a partir da última cheia', () {
      final m = calcularMedia(salvas, km: 2600, litros: 240, tanqueCheio: true);
      expect(m.kmRodados, 600);
      expect(m.media, closeTo(2.5, 1e-9));
    });

    test('média do período é km total sobre litros totais', () {
      final mp = mediaDoPeriodo(salvas, salvas);
      expect(mp.km, 1000);
      expect(mp.litros, 350);
    });

    test('nunca mistura caminhões: o odômetro é de cada caminhão', () {
      final todas = [
        abast('a1', 100000, partida: true, caminhao: 'c1'),
        abast('b1', 500000, partida: true, caminhao: 'c2'),
        abast('a2', 100800, litros: 320, caminhao: 'c1'),
        abast('b2', 500600, litros: 300, caminhao: 'c2'),
      ];
      expect(mediaDaLinha(todas, todas[2]).media, closeTo(2.5, 1e-9));
      expect(mediaDaLinha(todas, todas[3]).media, closeTo(2.0, 1e-9));
      final mp = mediaDoPeriodo(todas, todas);
      expect(mp.km, 1400);
      expect(mp.litros, 620);
      final por = mediaPorCaminhao(todas, todas);
      expect(por['c1']!.media, closeTo(2.5, 1e-9));
      expect(por['c2']!.media, closeTo(2.0, 1e-9));
      // Sem filtrar por caminhão, a prévia de um formulário erraria a conta:
      expect(calcularMedia(todas, km: 101600, litros: 320, tanqueCheio: true, caminhaoId: 'c1').kmRodados, 800);
    });

    test('primeiro abastecimento num caminhão novo é só ponto de partida', () {
      final todas = [
        abast('a1', 100000, partida: true, caminhao: 'c1'),
        abast('a2', 100800, litros: 320, caminhao: 'c1'),
        abast('n1', 7000, litros: 280, caminhao: 'c2'),
      ];
      final m = mediaDaLinha(todas, todas[2]);
      expect(m.media, isNull);
      expect(m.motivo, contains('primeira'));
    });

    test('abastecida apagada não entra na conta', () {
      final todas = [
        abast('1', 1000, partida: true),
        Abastecimento(
            id: '2', motoristaId: 'm1', caminhaoId: 'c1', data: DateTime.utc(1970), kmOdometro: 1500, litros: 200,
            apagadoEm: DateTime.utc(2026)),
        abast('3', 2000, litros: 400),
      ];
      expect(mediaDaLinha(todas, todas[2]).media, closeTo(2.5, 1e-9));
    });
  });

  group('Resumo', () {
    final fretes = [
      frete(pesoKg: 10000, valorTonelada: 10000, adiantamento: 60000, saldo: 30000, percentual: 10, sobreBruto: false, pedagio: 5000),
      frete(destino: 'C', pesoKg: 10000, valorTonelada: 20000, percentual: 10, sobreBruto: false),
    ];

    test('regra padrão: valor cheio, gastos da empresa, vale desconta', () {
      final r = calcularResumo(fretes: fretes, abastecimentos: [40000], gastos: [10000], vales: [5000]);
      expect(r.totalFretes, 90000);
      expect(r.comissao, closeTo(9000, 1e-9));
      expect(r.liquido, closeTo(4000, 1e-9));
      expect(r.totalGastoGeral, 50000);
      expect(r.fretesEmAberto, 1);
      expect(r.contratadoEmAberto, 200000);
      expect(r.totalContratado, 100000);
      expect(r.totalDescontoDoFrete, 10000);
      expect(r.comissaoDoCaminhao, closeTo(9000, 1e-9));
      expect(r.sobraDoCaminhao, closeTo(90000 - 40000 - 10000 - 9000, 1e-9));
      expect(r.totalPedagio, 5000);
    });

    test('gastos do bolso descontam', () {
      final r = calcularResumo(
        fretes: fretes,
        abastecimentos: [40000],
        gastos: [10000],
        vales: [5000],
        regras: const Regras(gastosDescontamDoLiquido: true),
      );
      expect(r.liquido, closeTo(9000 - 50000 - 5000, 1e-9));
    });

    test('só a minha parte: comissão é o próprio frete', () {
      final r = calcularResumo(
        fretes: fretes,
        abastecimentos: const [],
        gastos: const [],
        vales: [5000],
        regras: const Regras(freteRealEhValorCheio: false, valeDescontaDoLiquido: false),
      );
      expect(r.comissao, 90000);
      expect(r.liquido, 90000);
      expect(r.percentualMedio, 0);
    });

    test('regras vêm da configuração da empresa', () {
      final regras = Regras.daEmpresa(const ConfiguracaoEmpresa(gastosDescontamDoLiquido: true, valeDescontaDoLiquido: false));
      expect(regras.freteRealEhValorCheio, isTrue);
      expect(regras.gastosDescontamDoLiquido, isTrue);
      expect(regras.valeDescontaDoLiquido, isFalse);
    });
  });

  group('Períodos', () {
    final agora = DateTime(2026, 10, 11, 15, 0);

    test('este mês', () {
      final p = calcularPeriodo(TipoPeriodo.mesAtual, agora: agora)!;
      expect(dataTexto(p.inicio), '01/10/2026');
      expect(dataTexto(p.fim), '31/10/2026');
    });

    test('mês passado', () {
      final p = calcularPeriodo(TipoPeriodo.mesPassado, agora: agora)!;
      expect(dataTexto(p.inicio), '01/09/2026');
      expect(dataTexto(p.fim), '30/09/2026');
    });

    test('mês passado em janeiro volta para dezembro', () {
      final p = calcularPeriodo(TipoPeriodo.mesPassado, agora: DateTime(2027, 1, 5))!;
      expect(dataTexto(p.inicio), '01/12/2026');
      expect(dataTexto(p.fim), '31/12/2026');
    });

    test('últimos 7 dias inclui hoje', () {
      final p = calcularPeriodo(TipoPeriodo.seteDias, agora: agora)!;
      expect(dataTexto(p.inicio), '05/10/2026');
      expect(dataTexto(p.fim), '11/10/2026');
    });

    test('datas escolhidas fora de ordem não valem', () {
      expect(
        calcularPeriodo(TipoPeriodo.escolher, inicio: DateTime(2026, 10, 10), fim: DateTime(2026, 10, 1)),
        isNull,
      );
    });

    test('período inclui o último milissegundo do dia', () {
      final p = calcularPeriodo(TipoPeriodo.escolher, inicio: DateTime(2026, 10, 1), fim: DateTime(2026, 10, 1))!;
      expect(p.contem(DateTime(2026, 10, 1, 23, 59, 59)), isTrue);
      expect(p.contem(DateTime(2026, 10, 2)), isFalse);
    });

    test('janela da viagem', () {
      final cargas = [d(2026, 10, 2), d(2026, 10, 6), d(2026, 10, 10)];
      final meio = janelaDaViagem(d(2026, 10, 6), cargas, agora: agora);
      expect(dataTexto(meio.inicio), '07/10/2026');
      expect(dataTexto(meio.fim), '10/10/2026');
      final primeira = janelaDaViagem(d(2026, 10, 2), cargas, agora: agora);
      expect(dataTexto(primeira.inicio), '02/10/2026');
      expect(dataTexto(primeira.fim), '06/10/2026');
      final ultima = janelaDaViagem(d(2026, 10, 10), cargas, agora: agora);
      expect(dataTexto(ultima.fim), '11/10/2026');
    });

    test('acerto da viagem sempre inclui o próprio frete', () {
      final fretes = [
        frete(id: '1', origem: 'A', destino: 'B', dataCarga: d(2026, 10, 2), adiantamento: 100000),
        frete(id: '2', origem: 'B', destino: 'C', dataCarga: d(2026, 10, 6), adiantamento: 200000, saldo: 50000),
      ];
      Gasto gasto(String id, DateTime data, int valor) =>
          Gasto(id: id, motoristaId: 'm1', caminhaoId: 'c1', data: data, categoriaId: 'x', valorCentavos: valor);
      final gastos = [gasto('1', d(2026, 10, 6), 1000), gasto('2', d(2026, 10, 8), 2000)];
      final dr = montarDadosDaViagem(
        frete: fretes[1],
        fretes: fretes,
        abastecimentos: const [],
        vales: const [],
        gastos: gastos,
        ajustes: const [],
        regras: const Regras(),
        agora: agora,
      );
      expect(dr.fretes.single.id, '2');
      expect(dr.resultado.totalFretes, 250000);
      expect(dr.gastos.map((g) => g.id), ['2']);
      expect(dr.viagem, 'B para C');
    });

    test('a janela da viagem usa só as cargas do mesmo motorista', () {
      final fretes = [
        frete(id: '1', motorista: 'm1', dataCarga: d(2026, 10, 2)),
        frete(id: '2', motorista: 'm2', dataCarga: d(2026, 10, 4)),
        frete(id: '3', motorista: 'm1', dataCarga: d(2026, 10, 8)),
      ];
      final dr = montarDadosDaViagem(
        frete: fretes[0],
        fretes: fretes,
        abastecimentos: const [],
        vales: const [],
        gastos: const [],
        ajustes: const [],
        regras: const Regras(),
        agora: agora,
      );
      expect(dataTexto(dr.periodo.fim), '08/10/2026');
    });
  });

  group('Ajustes do gestor', () {
    AjusteGestor ajuste(String id, String campo, Object valor, DateTime quando) => AjusteGestor(
        id: id, tabelaAlvo: 'fretes', registroId: 'f1', campo: campo, valorNovo: valor, motivo: 'x', criadoEm: quando);

    test('vale o último ajuste de cada campo, como nas views do banco', () {
      final original = frete(id: 'f1', saldo: 195000, adiantamento: 480000).paraMapa();
      final efetivo = Frete.deMapa(aplicarAjustes(original, [
        ajuste('a', 'saldo_centavos', 200000, DateTime.utc(2026, 10, 1)),
        ajuste('b', 'saldo_centavos', 205000, DateTime.utc(2026, 10, 2)),
        ajuste('c', 'pedagio_centavos', 1500, DateTime.utc(2026, 10, 1)),
      ]));
      expect(efetivo.saldoCentavos, 205000);
      expect(efetivo.pedagioCentavos, 1500);
      expect(efetivo.adiantamentoCentavos, 480000);
      expect(efetivo.camposAjustados, ['pedagio_centavos', 'saldo_centavos']);
      expect(textoCamposAjustados(efetivo.camposAjustados), 'pedágio e saldo corrigidos pelo gestor');
    });

    test('ajuste de outro registro não muda nada', () {
      final original = frete(id: 'f2', saldo: 1).paraMapa();
      expect(Frete.deMapa(aplicarAjustes(original, [ajuste('a', 'saldo_centavos', 9, DateTime.utc(2026))])).saldoCentavos, 1);
    });
  });
}
