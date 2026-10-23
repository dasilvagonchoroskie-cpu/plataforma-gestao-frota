import 'dart:io';
import 'dart:typed_data';

import 'package:nucleo/nucleo.dart';
import 'package:test/test.dart';

FontesPdf fontes() {
  ByteData ler(String nome) => ByteData.sublistView(File('lib/fontes/$nome').readAsBytesSync());
  final a = FontesPdf.arquivos;
  return FontesPdf.deBytes(ler(a[0]), ler(a[1]), ler(a[2]), ler(a[3]));
}

/// Como o servidor manda o Baú (situacao_acesso -> empresa -> modalidades).
final bauDoServidor = <String, Object?>{
  'codigo': 'bau',
  'nome': 'Baú',
  'tipo': 'viagem',
  'ativa': true,
  'campos': [
    {'chave': 'placa_carreta', 'rotulo': 'Carreta', 'rotulo_padrao': 'Placa da carreta', 'tipo': 'placa',
      'obrigatorio': true, 'visivel': true, 'pode_ocultar': false, 'etapa': 'engate'},
    {'chave': 'entregas_cidades', 'rotulo': 'Cidades atendidas', 'tipo': 'cidades', 'obrigatorio': true,
      'visivel': true, 'pode_ocultar': true, 'etapa': 'entregas'},
    {'chave': 'observacao', 'rotulo': 'Observação', 'tipo': 'texto', 'obrigatorio': false, 'visivel': false,
      'pode_ocultar': true, 'etapa': 'desengate'},
    {'chave': 'lacre', 'rotulo': 'Número do lacre', 'tipo': 'texto', 'obrigatorio': true, 'visivel': true,
      'pode_ocultar': true, 'extra': true, 'etapa': 'engate'},
    {'chave': 'paletes', 'rotulo': 'Paletes', 'tipo': 'inteiro', 'obrigatorio': false, 'visivel': false,
      'pode_ocultar': true, 'extra': true, 'desativado': true, 'etapa': 'desengate'},
  ],
};

void main() {
  group('modalidades', () {
    test('lê a modalidade do servidor com os ajustes do dono', () {
      final m = Modalidade.deMapa(bauDoServidor);
      expect(m.porViagem, isTrue);
      expect(m.rotulo('placa_carreta', 'Placa da carreta'), 'Carreta');
      expect(m.obrigatorio('entregas_cidades'), isTrue);
      expect(m.visivel('observacao'), isFalse);
      expect(m.extras(etapa: EtapasViagem.engate).map((c) => c.chave), ['lacre']);
      expect(m.extras(), hasLength(1), reason: 'campo desativado não aparece no formulário');
      expect(m.rotulosExtras, {'lacre': 'Número do lacre', 'paletes': 'Paletes'});
    });

    test('sem a configuração (celular antigo), tudo funciona como antes', () {
      const m = Modalidade.graneleiro;
      expect(m.porViagem, isFalse);
      expect(m.rotulo('embarcador', 'Embarcador ou cliente'), 'Embarcador ou cliente');
      expect(m.visivel('saldo_centavos'), isTrue);
      expect(m.obrigatorio('saldo_centavos'), isFalse);
      expect(modalidadesDaEmpresa(null), isEmpty);
      expect(modalidadesDaEmpresa({'modalidades': [bauDoServidor]}).single.codigo, 'bau');
    });

    test('código a partir do nome', () {
      expect(codigoDoNome('Porta-contêiner'), 'porta_conteiner');
      expect(codigoDoNome('  Número do lacre '), 'numero_do_lacre');
      expect(codigoDoNome('3 eixos'), 'm_3_eixos');
    });

    test('mostra os campos novos com o nome certo', () {
      final m = Modalidade.deMapa(bauDoServidor);
      expect(linhasDosExtras({'lacre': '778', 'sem_nome': 'x', 'vazio': ''}, m), ['Número do lacre: 778', 'sem_nome: x']);
      expect(textoDoExtra(const CampoModalidade(chave: 'a', rotulo: 'A', tipo: TiposCampo.simNao), true), 'sim');
      expect(textoDoExtra(const CampoModalidade(chave: 'a', rotulo: 'A', tipo: TiposCampo.dinheiro), 12345), 'R\$ 123,45');
    });
  });

  group('viagens', () {
    test('ida e volta do mapa, com a placa arrumada', () {
      final v = Viagem(
        id: 'v1', motoristaId: 'm1', caminhaoId: 'c1', placaCarreta: 'abc-1d23', engateLocal: 'Cajamar',
        engateEm: DateTime.utc(2026, 10, 10, 11), entregasQuantidade: 2, entregasCidades: const ['Campinas', 'Limeira'],
        extras: const {'lacre': '778'},
      );
      final m = v.paraMapa();
      expect(m['placa_carreta'], 'ABC1D23');
      expect(m.containsKey('desengate_em'), isFalse);
      final de = Viagem.deMapa(m);
      expect(de.emAndamento, isTrue);
      expect(de.entregasCidades, ['Campinas', 'Limeira']);
      expect(de.extras['lacre'], '778');
      expect(de.rota, 'Cajamar para em andamento');
      final fechada = de.copyWith(desengateLocal: 'Ribeirão Preto', desengateEm: DateTime.utc(2026, 10, 12, 21));
      expect(fechada.emAndamento, isFalse);
      expect(fechada.duracao, const Duration(days: 2, hours: 10));
      expect(fechada.copyWith(reabrir: true).emAndamento, isTrue);
    });
  });

  group('acerto', () {
    test('a mesma conta do servidor', () {
      const descontos = [DescontoAcerto(descricao: 'Multa', valorCentavos: 10000)];
      expect(
        calcularParaReceber(comissaoCentavos: 150000, descontos: descontos, valesCentavos: 20000,
            dieselCentavos: 50000, gastosCentavos: 5000, regras: const Regras()),
        120000,
      );
      expect(
        calcularParaReceber(comissaoCentavos: 150000, descontos: const [], valesCentavos: 20000,
            dieselCentavos: 50000, gastosCentavos: 5000,
            regras: const Regras(gastosDescontamDoLiquido: true)),
        75000,
      );
    });

    test('lê o acerto do servidor', () {
      final a = Acerto.deMapa({
        'id': 'a1', 'motorista_id': 'm1', 'periodo_inicio': '2026-10-01', 'periodo_fim': '2026-10-15',
        'comissao_centavos': 150000, 'descontos': [{'descricao': 'Multa', 'valor_centavos': 10000}],
        'total_descontos_centavos': 10000, 'vales_centavos': 20000, 'diesel_centavos': 50000,
        'gastos_centavos': 5000, 'desconta_vales': true, 'desconta_gastos': false, 'para_receber_centavos': 120000,
        'quantidade_viagens': 1, 'fechado_em': '2026-10-16T12:00:00Z',
      });
      expect(a.periodoTexto, '01/10/2026 a 15/10/2026');
      expect(a.cobre(DateTime(2026, 10, 15, 23, 50)), isTrue);
      expect(a.cobre(DateTime(2026, 10, 16)), isFalse);
      expect(contaDoAcerto(a), 'Comissão R\$ 1.500,00  menos descontos R\$ 100,00  menos vales R\$ 200,00');
      expect(Acerto.deMapa(a.paraMapa()).paraReceberCentavos, 120000);
    });

    test('PDF das viagens e do acerto', () async {
      final m = Modalidade.deMapa(bauDoServidor);
      final viagens = [
        Viagem(id: 'v1', motoristaId: 'm1', caminhaoId: 'c1', placaCarreta: 'ABC1D23', engateLocal: 'Cajamar SP',
            engateEm: DateTime(2026, 10, 10, 8), desengateLocal: 'Ribeirão Preto SP', desengateEm: DateTime(2026, 10, 12, 18),
            entregasQuantidade: 3, entregasCidades: const ['Campinas', 'Limeira', 'Araras'], extras: const {'lacre': '778'}),
        Viagem(id: 'v2', motoristaId: 'm1', caminhaoId: 'c1', placaCarreta: 'XYZ1234', engateLocal: 'Ribeirão Preto SP',
            engateEm: DateTime(2026, 10, 13, 7)),
      ];
      final vales = [Vale(id: 'x', motoristaId: 'm1', data: DateTime(2026, 10, 11), valorCentavos: 20000)];
      final acerto = Acerto(
        id: 'a1', motoristaId: 'm1', periodoInicio: DateTime(2026, 10, 1), periodoFim: DateTime(2026, 10, 15),
        comissaoCentavos: 150000, descontos: const [DescontoAcerto(descricao: 'Multa', valorCentavos: 10000)],
        totalDescontosCentavos: 10000, valesCentavos: 20000, paraReceberCentavos: 120000, quantidadeViagens: 2,
        fechadoEm: DateTime(2026, 10, 16, 9),
      );
      final d = montarDadosDoAcerto(
        acerto: acerto, viagens: viagens, abastecimentos: const [], vales: vales, gastos: const [],
        regras: const Regras(), motorista: 'José Baú', placa: 'ABC1D23', empresa: 'Transportes X', modalidade: m,
      );
      expect(d.viagens, hasLength(2));
      expect(d.porViagem, isTrue);
      final bytes = await gerarPdf(d, fontes(), agora: DateTime(2026, 10, 16, 10));
      expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
      Directory('build').createSync(recursive: true);
      File('build/exemplo_acerto_bau.pdf').writeAsBytesSync(bytes);
      expect(nomeDoArquivoPdf(d), 'Frota_Jose_ABC1D23_acerto_01-10-2026_a_15-10-2026.pdf');

      for (final c in ConteudoRelatorio.values) {
        final r = montarDados(
          fretes: const [], abastecimentos: const [], vales: vales, gastos: const [], ajustes: const [],
          periodo: calcularPeriodo(TipoPeriodo.mesAtual, agora: DateTime(2026, 10, 20))!, regras: const Regras(),
          conteudo: c, viagens: viagens, porViagem: true, modalidade: m, motorista: 'José Baú',
        );
        expect((await gerarPdf(r, fontes())).length, greaterThan(5000), reason: '$c');
      }

      final csv = csvViagens(viagens, motoristas: const {'m1': 'José'}, placas: const {'c1': 'DEF4567'}, modalidade: m);
      expect(csv, contains('José;DEF-4567;ABC1D23;Cajamar SP;12/10/2026 às 18:00;Ribeirão Preto SP;3;Campinas, Limeira, Araras;;778'));
      expect(csv, contains('em andamento'));
      expect(csv.split('\n').first, contains('Número do lacre'));
    });
  });

  test('frete guarda a modalidade e os campos novos', () {
    final f = Frete.deMapa({
      'id': 'f1', 'motorista_id': 'm', 'caminhao_id': 'c', 'origem': 'A', 'destino': 'B',
      'data_carga': '2026-10-01T03:00:00Z', 'modalidade': 'cacamba', 'extras': {'ticket': '778'},
    });
    expect(f.modalidade, 'cacamba');
    expect(f.paraMapa()['extras'], {'ticket': '778'});
    expect(f.copyWith(extras: {'ticket': ''}).paraMapa()['extras'], {'ticket': ''});
    final antigo = Frete.deMapa({'id': 'f1', 'motorista_id': 'm', 'caminhao_id': 'c', 'origem': 'A', 'destino': 'B',
      'data_carga': '2026-10-01T03:00:00Z'});
    expect(antigo.paraMapa().containsKey('extras'), isFalse, reason: 'frete antigo vai igual a antes');
    expect(antigo.paraMapa().containsKey('modalidade'), isFalse);
  });
}
