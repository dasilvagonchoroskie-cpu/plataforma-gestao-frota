// Testes da fila offline e da sincronização (seção 8 da arquitetura):
// reenvio sem duplicar, internet caindo no meio, app fechado durante o envio,
// dois motoristas offline, relógio errado e ajustes do gestor.
import 'package:flutter_test/flutter_test.dart';
import 'package:motorista/dados/armazenamento.dart';
import 'package:motorista/dados/dados.dart';
import 'package:motorista/dados/sincronizador.dart';
import 'package:nucleo/nucleo.dart';

import 'apoio.dart';

Vale vale(String id, int centavos, {DateTime? data}) =>
    Vale(id: id, motoristaId: motoristaA, data: data ?? DateTime.utc(2026, 10, 10), valorCentavos: centavos);

void main() {
  test('grava primeiro no celular e só tira da fila depois que a nuvem confirma', () async {
    final s = servidorComCadastros();
    final c = await celular(s);
    final sync = c.read(sincronizadorProvider.notifier);
    await sync.baixar(tudo: true);
    await c.read(dadosProvider.notifier).recarregar();

    s.online = false;
    await c.read(dadosProvider.notifier).salvarVale(vale('v1', 50000));
    var d = c.read(dadosProvider).requireValue;
    expect(d.vales.single.valorCentavos, 50000);
    expect(d.quantidadePendente, 1);

    await sync.sincronizar();
    expect(c.read(sincronizadorProvider).erro, contains('internet'));
    expect(c.read(dadosProvider).requireValue.quantidadePendente, 1, reason: 'sem internet nada sai da fila');

    s.online = true;
    await sync.sincronizar();
    d = c.read(dadosProvider).requireValue;
    expect(d.quantidadePendente, 0);
    expect(s.nuvem['vales']!['v1']!['valor_centavos'], 50000);
    expect(c.read(sincronizadorProvider).erro, isNull);
  });

  test('internet caindo no meio do lote: reenvia sem duplicar', () async {
    final s = servidorComCadastros();
    final c = await celular(s);
    final sync = c.read(sincronizadorProvider.notifier);
    await c.read(dadosProvider.notifier).salvarVale(vale('v1', 1000));
    await c.read(dadosProvider.notifier).salvarVale(vale('v2', 2000));

    s.perderResposta = true; // a nuvem gravou, mas a resposta não voltou
    await sync.sincronizar();
    expect(c.read(dadosProvider).requireValue.quantidadePendente, 2);
    expect(s.nuvem['vales']!.length, 2);

    await sync.sincronizar(); // manda o mesmo lote de novo
    expect(c.read(dadosProvider).requireValue.quantidadePendente, 0);
    expect(s.nuvem['vales']!.length, 2, reason: 'o id é do celular: reenviar não duplica');
    expect(s.lotesRecebidos, 2);
  });

  test('app fechado durante o envio: a fila continua no celular', () async {
    final s = servidorComCadastros();
    final a = ArmazenamentoMemoria();
    final c1 = await celular(s, armazenamento: a);
    await c1.read(dadosProvider.notifier).salvarVale(vale('v1', 1000));
    s.perderResposta = true;
    await c1.read(sincronizadorProvider.notifier).sincronizar();
    c1.dispose(); // fechou o app

    final c2 = await celular(s, armazenamento: a); // abriu de novo
    expect(c2.read(dadosProvider).requireValue.quantidadePendente, 1);
    await c2.read(sincronizadorProvider.notifier).sincronizar();
    expect(c2.read(dadosProvider).requireValue.quantidadePendente, 0);
    expect(s.nuvem['vales']!.length, 1);
  });

  test('mexer no lançamento enquanto ele está sendo enviado não perde a mudança', () async {
    final a = ArmazenamentoMemoria();
    await a.enfileirar('vales', 'v1', vale('v1', 1000).paraMapa());
    final enviado = (await a.fila()).single;
    await a.enfileirar('vales', 'v1', vale('v1', 1500).paraMapa()); // mudou antes da resposta
    await a.confirmarEnvio(enviado.seq, enviado.versao);
    final fila = await a.fila();
    expect(fila.single.dados['valor_centavos'], 1500);
    expect(fila.single.versao, 2);
  });

  test('dois motoristas offline lançando ao mesmo tempo, depois online', () async {
    final s = servidorComCadastros();
    final ca = await celular(s);
    final sb = s; // mesma nuvem
    s.online = false;
    await ca.read(dadosProvider.notifier).salvarVale(vale('va', 1000));

    final aB = ArmazenamentoMemoria();
    final cb = await celular(ServidorFalsoDe(sb, motoristaB), armazenamento: aB);
    await cb.read(dadosProvider.notifier).salvarVale(
        Vale(id: 'vb', motoristaId: motoristaB, data: DateTime.utc(2026, 10, 10), valorCentavos: 2000));

    s.online = true;
    await ca.read(sincronizadorProvider.notifier).sincronizar();
    await cb.read(sincronizadorProvider.notifier).sincronizar();
    expect(s.nuvem['vales']!.keys.toSet(), {'va', 'vb'});
    expect(ca.read(dadosProvider).requireValue.vales.map((v) => v.id), ['va']);
    expect(cb.read(dadosProvider).requireValue.vales.map((v) => v.id), ['vb']);
  });

  test('relógio do celular errado: a data escolhida fica, a nuvem decide o resto', () async {
    final s = servidorComCadastros();
    final c = await celular(s, agora: DateTime.utc(2031, 1, 1)); // relógio adiantado
    await c.read(dadosProvider.notifier).salvarVale(vale('v1', 1000, data: DateTime.utc(2026, 10, 3)));
    await c.read(sincronizadorProvider.notifier).sincronizar();
    expect(s.nuvem['vales']!['v1']!['data'], '2026-10-03T00:00:00.000Z');
    expect(s.nuvem['vales']!['v1']!['atualizado_em'], s.relogio.toIso8601String());
  });

  test('celular novo: entra e recupera todo o histórico da nuvem', () async {
    final s = servidorComCadastros();
    s.colocar('vales', vale('antigo', 9900).paraMapa());
    s.colocar('uso_caminhao', UsoCaminhao(id: 'u1', motoristaId: motoristaA, caminhaoId: caminhao2,
        inicioEm: DateTime.utc(2026, 9, 1)).paraMapa());
    final c = await celular(s);
    await c.read(sincronizadorProvider.notifier).baixar(tudo: true);
    await c.read(dadosProvider.notifier).recarregar();
    final d = c.read(dadosProvider).requireValue;
    expect(d.vales.single.valorCentavos, 9900);
    expect(d.caminhaoAtual?.placa, 'DEF4567');
    expect(d.categoriasAtivas.single.nome, 'Borracharia');
  });

  test('o que o motorista mudou e não enviou vale mais que a cópia da nuvem', () async {
    final s = servidorComCadastros();
    s.colocar('vales', vale('v1', 1000).paraMapa());
    final c = await celular(s);
    await c.read(sincronizadorProvider.notifier).baixar(tudo: true);
    s.online = false;
    await c.read(dadosProvider.notifier).salvarVale(vale('v1', 1234));
    s.online = true;
    s.relogio = s.relogio.add(const Duration(hours: 1));
    s.colocar('vales', vale('v1', 1000).paraMapa()); // a nuvem ainda tem o valor antigo
    await c.read(sincronizadorProvider.notifier).baixar();
    await c.read(dadosProvider.notifier).recarregar();
    expect(c.read(dadosProvider).requireValue.vales.single.valorCentavos, 1234);
  });

  test('ajuste do gestor: o celular mostra o valor corrigido e não deixa mudar', () async {
    final s = servidorComCadastros();
    final c = await celular(s);
    await c.read(dadosProvider.notifier).salvarVale(vale('v1', 1000));
    await c.read(sincronizadorProvider.notifier).sincronizar();
    s.ajustes.add({
      'id': 'aj1', 'tabela_alvo': 'vales', 'registro_id': 'v1', 'campo': 'valor_centavos',
      'valor_antigo': 1000, 'valor_novo': 800, 'motivo': 'Conferido no recibo',
      'criado_em': '2026-10-16T10:00:00Z', 'apagado': false,
    });
    await c.read(sincronizadorProvider.notifier).sincronizar();
    final d = c.read(dadosProvider).requireValue;
    expect(d.vales.single.valorCentavos, 800);
    expect(d.vales.single.ajustado, isTrue);
    expect(c.read(dadosProvider.notifier).podeAlterar('v1'), isFalse);
  });

  test('mudou offline e o gestor já tinha ajustado: volta o que está na nuvem, com aviso', () async {
    final s = servidorComCadastros();
    final c = await celular(s);
    await c.read(dadosProvider.notifier).salvarVale(vale('v1', 1000));
    await c.read(sincronizadorProvider.notifier).sincronizar();
    s.ajustes.add({
      'id': 'aj1', 'tabela_alvo': 'vales', 'registro_id': 'v1', 'campo': 'valor_centavos',
      'valor_novo': 800, 'motivo': 'Recibo', 'criado_em': '2026-10-16T10:00:00Z',
    });
    await c.read(dadosProvider.notifier).salvarVale(vale('v1', 5000)); // ainda não sabia do ajuste
    await c.read(sincronizadorProvider.notifier).sincronizar();
    final d = c.read(dadosProvider).requireValue;
    expect(d.recusados.single.mensagem, contains('patrão já corrigiu'));
    expect(d.vales.single.valorCentavos, 800, reason: 'original da nuvem + ajuste');
    await c.read(dadosProvider.notifier).dispensarRecusado(d.recusados.single);
    expect(c.read(dadosProvider).requireValue.recusados, isEmpty);
  });

  test('troca de caminhão no meio do mês: cada lançamento fica no seu caminhão', () async {
    final s = servidorComCadastros();
    final c = await celular(s, agora: DateTime.utc(2026, 10, 1, 8));
    await c.read(sincronizadorProvider.notifier).baixar(tudo: true);
    await c.read(dadosProvider.notifier).recarregar();
    final dados = c.read(dadosProvider.notifier);
    await dados.trocarCaminhao(caminhao1);
    final f1 = dados.novoFrete().copyWith(origem: 'A', destino: 'B', adiantamentoCentavos: 100000);
    await dados.salvarFrete(f1);
    await dados.trocarCaminhao(caminhao2);
    final f2 = dados.novoFrete().copyWith(origem: 'B', destino: 'C', adiantamentoCentavos: 200000);
    await dados.salvarFrete(f2);
    final d = c.read(dadosProvider).requireValue;
    expect(d.freteComId(f1.id)!.caminhaoId, caminhao1);
    expect(d.freteComId(f2.id)!.caminhaoId, caminhao2);
    expect(d.caminhaoAtual!.placa, 'DEF4567');
    expect(d.dadosDoPeriodo(calcularPeriodo(TipoPeriodo.mesAtual, agora: DateTime(2026, 10, 15))!).placa, 'Vários');
  });

  test('"não achei meu caminhão" offline, e o gestor já tinha a placa', () async {
    final s = servidorComCadastros();
    s.placasDoGestor['GHI2J34'] = 'cam-do-gestor';
    final c = await celular(s);
    await c.read(sincronizadorProvider.notifier).baixar(tudo: true);
    await c.read(dadosProvider.notifier).recarregar();
    final dados = c.read(dadosProvider.notifier);
    s.online = false;
    final id = await dados.cadastrarCaminhao('ghi-2j34');
    await dados.salvarFrete(dados.novoFrete().copyWith(origem: 'A', destino: 'B'));
    expect(c.read(dadosProvider).requireValue.caminhaoAtual!.confirmado, isFalse);

    s.online = true;
    await c.read(sincronizadorProvider.notifier).sincronizar();
    final d = c.read(dadosProvider).requireValue;
    expect(d.caminhaoPorId(id), isNull, reason: 'o caminhão do celular deu lugar ao do gestor');
    expect(d.caminhaoAtualId, 'cam-do-gestor');
    expect(d.fretes.single.caminhaoId, 'cam-do-gestor');
    expect(d.quantidadePendente, 0);
  });

  test('média do diesel no celular nunca mistura caminhões', () async {
    final s = servidorComCadastros();
    final c = await celular(s);
    final dados = c.read(dadosProvider.notifier);
    await dados.salvarPontoDePartida(caminhaoId: caminhao1, km: 100000);
    await dados.salvarPontoDePartida(caminhaoId: caminhao2, km: 500000);
    Abastecimento ab(String id, String cam, double km, double litros) => Abastecimento(
        id: id, motoristaId: motoristaA, caminhaoId: cam, data: DateTime.utc(2026, 10, 5), kmOdometro: km, litros: litros);
    await dados.salvarAbastecimento(ab('a1', caminhao1, 100800, 320));
    await dados.salvarAbastecimento(ab('b1', caminhao2, 500600, 300));
    final d = c.read(dadosProvider).requireValue;
    expect(mediaDaLinha(d.abastecimentos, d.abastecimentos.firstWhere((a) => a.id == 'a1')).media, closeTo(2.5, 1e-9));
    expect(mediaDaLinha(d.abastecimentos, d.abastecimentos.firstWhere((a) => a.id == 'b1')).media, closeTo(2.0, 1e-9));
  });

  test('mudança do km inicial fica registrada com motivo', () async {
    final s = servidorComCadastros();
    final c = await celular(s);
    final dados = c.read(dadosProvider.notifier);
    await dados.salvarPontoDePartida(caminhaoId: caminhao1, km: 100000);
    await dados.salvarPontoDePartida(caminhaoId: caminhao1, km: 100500, motivo: 'Painel aferido');
    final d = c.read(dadosProvider).requireValue;
    expect(d.pontoDePartidaDo(caminhao1)!.km, 100500);
    expect(d.ajustesKm.single.kmAnterior, 100000);
    expect(d.ajustesKm.single.motivo, 'Painel aferido');
  });

  test('motorista desligado pela empresa: avisa e não apaga nada do celular', () async {
    final s = servidorComCadastros();
    final c = await celular(s);
    await c.read(dadosProvider.notifier).salvarVale(vale('v1', 1000));
    await c.read(sincronizadorProvider.notifier).sincronizar();
    s.motoristaId = 'outro'; // situação passa a vir sem este motorista ativo
    final desligado = _ServidorDesligado(s);
    final c2 = await celular(desligado, armazenamento: c.read(armazenamentoProvider));
    await c2.read(sincronizadorProvider.notifier).sincronizar();
    expect(c2.read(sincronizadorProvider).desligado, isTrue);
    expect(c2.read(dadosProvider).requireValue.vales, isNotEmpty);
  });
}

/// Mesmo servidor, mas falando como outro motorista (mesma nuvem).
class ServidorFalsoDe extends ServidorFalso {
  ServidorFalsoDe(this.base, String motorista) : super(motoristaId: motorista);
  final ServidorFalso base;

  @override
  Map<String, Map<String, Map<String, Object?>>> get nuvem => base.nuvem;

  @override
  bool get online => base.online;
}

class _ServidorDesligado extends ServidorFalsoDe {
  _ServidorDesligado(ServidorFalso base) : super(base, motoristaA);

  @override
  Map<String, Object?> situacaoAtual() => situacaoDe(motoristaA, ativo: false);
}
