import 'dart:io';
import 'dart:typed_data';

import 'package:nucleo/nucleo.dart';
import 'package:test/test.dart';

FontesPdf fontes() {
  ByteData ler(String nome) => ByteData.sublistView(File('lib/fontes/$nome').readAsBytesSync());
  final a = FontesPdf.arquivos;
  return FontesPdf.deBytes(ler(a[0]), ler(a[1]), ler(a[2]), ler(a[3]));
}

/// Como o servidor manda (situacao_acesso -> empresa).
final empresaDoServidor = <String, Object?>{
  'paradas_ativas': true,
  'limite_sem_descanso_minutos': 330,
  'motivos_parada': [
    {'codigo': 'cafe', 'nome': 'Café ou pausa curta', 'conta_como_descanso': false, 'ativo': true},
    {'codigo': 'refeicao', 'nome': 'Refeição', 'conta_como_descanso': true, 'ativo': true},
    {'codigo': 'descanso', 'nome': 'Descanso', 'conta_como_descanso': true, 'ativo': true},
    {'codigo': 'pernoite', 'nome': 'Pernoite', 'conta_como_descanso': true, 'ativo': true},
    {'codigo': 'abastecimento', 'nome': 'Abastecimento', 'conta_como_descanso': false, 'ativo': true},
    {'codigo': 'outro', 'nome': 'Outro', 'conta_como_descanso': false, 'ativo': true},
    {'codigo': 'antigo', 'nome': 'Antigo', 'conta_como_descanso': false, 'ativo': false},
  ],
};

DateTime h(int dia, int hora, [int minuto = 0]) => DateTime(2026, 10, dia, hora, minuto);

Parada parada(String id, String motivo, DateTime inicio, [DateTime? fim, bool ajustado = false]) =>
    Parada(id: id, motoristaId: 'm1', caminhaoId: 'c1', motivo: motivo, inicioEm: inicio, fimEm: fim, ajustado: ajustado);

void main() {
  final config = ConfiguracaoParadas.deMapa(empresaDoServidor);
  final semana = Periodo(h(5, 0), DateTime(2026, 10, 11, 23, 59, 59));

  // Segunda: pernoite até 05:00, café 07:00-07:15, refeição 11:30-12:30,
  // abastecimento 15:00-15:20, descanso 18:40-19:10 (6h10 depois da refeição),
  // pernoite 23:00 até 05:30 de terça.
  final paradas = [
    parada('p0', 'pernoite', h(4, 22), h(5, 5)),
    parada('p1', 'cafe', h(5, 7), h(5, 7, 15)),
    parada('p2', 'refeicao', h(5, 11, 30), h(5, 12, 30)),
    parada('p3', 'abastecimento', h(5, 15), h(5, 15, 20)),
    parada('p4', 'descanso', h(5, 18, 40), h(5, 19, 10), true),
    parada('p5', 'pernoite', h(5, 23), h(6, 5, 30)),
    Parada(id: 'px', motoristaId: 'm1', motivo: 'descanso', inicioEm: h(5, 16), fimEm: h(5, 16, 5), apagadoEm: h(5, 17)),
  ];

  group('configuração', () {
    test('lê o que a empresa escolheu, sem número fixo no app', () {
      expect(config.ativas, isTrue);
      expect(config.limiteMinutos, 330);
      expect(config.motivos, hasLength(7));
      expect(config.motivosAtivos.map((m) => m.codigo), isNot(contains('antigo')));
      expect([for (final m in config.motivos) if (m.contaComoDescanso) m.codigo], ['refeicao', 'descanso', 'pernoite']);
      expect(nomeDoMotivo('cafe', config.motivos), 'Café ou pausa curta');
      expect(nomeDoMotivo('sumiu', config.motivos), 'sumiu');
    });

    test('desligado por padrão e sem limite quando o servidor não manda', () {
      final c = ConfiguracaoParadas.deMapa(const {});
      expect(c.ativas, isFalse);
      expect(c.limiteMinutos, isNull);
      expect(c.motivos, isEmpty);
      expect(const ConfiguracaoParadas().ativas, isFalse);
    });
  });

  group('parada', () {
    test('ida e volta pelo servidor', () {
      final p = parada('p9', 'outro', h(5, 8), h(5, 9), true).copyWith(descricao: 'Esperando a balança');
      final m = p.paraMapa();
      expect(m['motivo'], 'outro');
      expect(m['descricao'], 'Esperando a balança');
      expect(m['ajustado'], isTrue);
      expect(m.containsKey('fim_em'), isTrue);
      final volta = Parada.deMapa(m);
      expect(volta.fimEm!.isAtSameMomentAs(h(5, 9)), isTrue);
      expect(volta.ajustado, isTrue);
      expect(volta.duracao(h(5, 20)), const Duration(hours: 1));
    });

    test('aberta até retomar; a duração corre até agora', () {
      final aberta = parada('p9', 'carga', h(6, 8));
      expect(aberta.emAndamento, isTrue);
      expect(aberta.paraMapa().containsKey('fim_em'), isFalse);
      expect(aberta.duracao(h(6, 9, 45)), const Duration(hours: 1, minutes: 45));
      expect(paradaAberta([...paradas, aberta])?.id, 'p9');
      expect(paradaAberta(paradas), isNull);
      final fechada = aberta.copyWith(fimEm: h(6, 10), ajustado: true);
      expect(fechada.emAndamento, isFalse);
      expect(fechada.copyWith(reabrir: true).emAndamento, isTrue);
    });

    test('textos de tempo', () {
      expect(duracaoTexto(const Duration(minutes: 45)), '45 min');
      expect(duracaoTexto(const Duration(minutes: 65)), '1h05');
      expect(duracaoTexto(const Duration(hours: 26, minutes: 10)), '26h10');
      expect(duracaoTexto(const Duration(minutes: -3)), '0 min');
      expect(limiteTexto(330), '5h30');
      expect(horaTexto(h(5, 7, 5)), '07:05');
    });
  });

  group('intervalo sem descanso', () {
    final r = resumirParadas(
      paradas: paradas, motivos: config.motivos, periodo: semana, limiteMinutos: 330, agora: h(20, 12),
    );

    test('só refeição, descanso e pernoite contam como descanso', () {
      expect(r.paradas.map((p) => p.id), ['p0', 'p1', 'p2', 'p3', 'p4', 'p5'], reason: 'a apagada fica de fora');
      // Café e abastecimento não quebram o intervalo: de 12:30 até 18:40 = 6h10.
      expect(r.intervalos.map((i) => duracaoTexto(i.duracao)), ['6h30', '6h10', '3h50']);
      expect(duracaoTexto(r.maior!.duracao), '6h30');
      expect(r.maior!.inicio, h(5, 5));
    });

    test('destaca o que passa do limite da empresa', () {
      expect(r.acimaDoLimite, hasLength(2));
      expect(r.intervalos.last.acimaDoLimite, isFalse);
      final folgado = resumirParadas(
        paradas: paradas, motivos: config.motivos, periodo: semana, limiteMinutos: 400, agora: h(20, 12),
      );
      expect(folgado.acimaDoLimite, isEmpty, reason: 'o limite é da empresa, não do app');
      final semLimite = resumirParadas(
        paradas: paradas, motivos: config.motivos, periodo: semana, limiteMinutos: null, agora: h(20, 12),
      );
      expect(semLimite.acimaDoLimite, isEmpty);
      expect(semLimite.maior, isNotNull);
    });

    test('tempo parado e tempo de descanso', () {
      // 7h + 15min + 1h + 20min + 30min + 6h30 = 15h35; descanso: 7h + 1h + 30min + 6h30 = 15h.
      expect(duracaoTexto(r.tempoParado), '15h35');
      expect(duracaoTexto(r.tempoDescanso), '15h00');
      expect(r.temDescanso, isTrue);
    });

    test('período de hoje: conta também desde o último descanso até agora', () {
      final hoje = Periodo(h(6, 0), DateTime(2026, 10, 6, 23, 59, 59));
      final agora = resumirParadas(
        paradas: paradas, motivos: config.motivos, periodo: hoje, limiteMinutos: 330, agora: h(6, 12),
      );
      expect(agora.intervalos.single.ateAgora, isTrue);
      expect(duracaoTexto(agora.intervalos.single.duracao), '6h30');
      expect(agora.intervalos.single.acimaDoLimite, isTrue);
      expect(textoDoIntervalo(agora.intervalos.single), 'de 6 out 05:30 a agora');
      expect(semDescansoDesde(paradas, config.motivos), h(6, 5, 30));
    });

    test('descansando agora: não há intervalo aberto', () {
      final hoje = Periodo(h(6, 0), DateTime(2026, 10, 6, 23, 59, 59));
      final comAberta = [...paradas, parada('p6', 'refeicao', h(6, 11, 30))];
      final r2 = resumirParadas(
        paradas: comAberta, motivos: config.motivos, periodo: hoje, limiteMinutos: 330, agora: h(6, 12),
      );
      expect(r2.intervalos.map((i) => duracaoTexto(i.duracao)), ['6h00']);
      expect(r2.intervalos.single.ateAgora, isFalse);
      expect(semDescansoDesde(comAberta, config.motivos), isNull);
    });

    test('sem descanso no período: nada para medir', () {
      final soCafe = [parada('a', 'cafe', h(8, 7), h(8, 7, 10))];
      final r3 = resumirParadas(
        paradas: soCafe, motivos: config.motivos, periodo: semana, limiteMinutos: 330, agora: h(20, 12),
      );
      expect(r3.temDescanso, isFalse);
      expect(r3.maior, isNull);
      expect(semDescansoDesde(soCafe, config.motivos), isNull);
    });
  });

  group('relatório', () {
    final r = resumirParadas(
      paradas: paradas, motivos: config.motivos, periodo: semana, limiteMinutos: 330, agora: h(20, 12),
    );
    final d = DadosParadas(
      periodo: semana, resumo: r, motivos: config.motivos, empresa: 'Transportes X', motorista: 'João Batista',
      placasPorCaminhao: const {'c1': 'ABC1D23'},
    );

    test('PDF com o aviso de que não substitui o tacógrafo', () async {
      final bytes = await gerarPdfParadas(d, fontes(), agora: h(20, 12));
      expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
      expect(bytes.length, greaterThan(5000));
      Directory('build').createSync(recursive: true);
      File('build/exemplo_paradas.pdf').writeAsBytesSync(bytes);
      expect(nomeDoArquivoParadas(d), 'Frota_Joao_paradas_05-10-2026_a_11-10-2026.pdf');
      expect(avisoParadas, 'Registro interno feito pelo motorista; não substitui o tacógrafo.');

      final vazio = DadosParadas(
        periodo: semana,
        resumo: resumirParadas(paradas: const [], motivos: config.motivos, periodo: semana, limiteMinutos: 330, agora: h(20, 12)),
        motivos: config.motivos,
      );
      expect((await gerarPdfParadas(vazio, fontes())).length, greaterThan(3000));
    });

    test('planilha com o tempo sem descanso antes de cada descanso', () {
      final csv = csvParadas(d, agora: h(20, 12));
      expect(csv, startsWith('\uFEFFMotorista;Caminhão;Motivo'), reason: 'o Excel abre com acentos certos');
      final linhas = csv.trim().split('\n');
      expect(linhas, hasLength(1 + 6 + 2));
      final descanso = linhas.firstWhere((l) => l.contains(';Descanso;'));
      expect(descanso, contains(';ABC1D23;'));
      expect(descanso, contains(';6h10;sim;sim'), reason: 'sem descanso antes, acima do limite e horário informado depois');
      expect(linhas.firstWhere((l) => l.contains(';Abastecimento;')), contains(';não;;;não'));
      expect(linhas.last, '"$avisoParadas"', reason: 'tem ponto e vírgula, então vai entre aspas');
      expect(nomeDoArquivoParadas(d, extensao: 'csv'), endsWith('.csv'));
    });
  });
}
