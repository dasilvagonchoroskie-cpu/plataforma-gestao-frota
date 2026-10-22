import 'dart:convert';

import 'package:drift/drift.dart';

import 'banco.dart';

/// Um item da fila de envio.
class ItemFila {
  const ItemFila({
    required this.seq,
    required this.tabela,
    required this.registroId,
    required this.dados,
    required this.versao,
    required this.situacao,
    this.mensagem,
  });

  final int seq;
  final String tabela;
  final String registroId;
  final Map<String, Object?> dados;
  final int versao;

  /// 'pendente' (esperando internet) ou 'recusado' (o servidor não aceitou).
  final String situacao;
  final String? mensagem;

  String get chave => '$tabela:$registroId';
}

/// Onde o app guarda tudo no celular. A versão de verdade usa SQLite (drift);
/// os testes usam a da memória.
abstract class Armazenamento {
  Future<List<Map<String, Object?>>> registros(String tabela);
  Future<Map<String, Object?>?> registro(String tabela, String id);
  Future<void> gravarRegistros(String tabela, List<Map<String, Object?>> lista);
  Future<void> apagarRegistro(String tabela, String id);

  /// Põe (ou atualiza) o registro na fila. Se já tem um item esperando do
  /// mesmo registro, troca os dados por estes (o servidor recebe o estado
  /// mais novo) e sobe a versão.
  Future<void> enfileirar(String tabela, String registroId, Map<String, Object?> dados);
  Future<List<ItemFila>> fila({String? situacao, int limite = 1000});

  /// Tira da fila se ninguém mexeu no registro enquanto ele era enviado.
  Future<void> confirmarEnvio(int seq, int versao);
  Future<void> marcarRecusado(int seq, int versao, String mensagem);
  Future<void> removerDaFila(String tabela, String registroId);

  /// Troca o id de um caminhão nos registros e na fila (o gestor já tinha a placa).
  Future<void> trocarCaminhao(String de, String para);

  Future<String?> lerEstado(String chave);
  Future<void> gravarEstado(String chave, String? valor);
  Future<void> limparTudo();
}

/// O que fica guardado no celular da situação da conta: sem CPF e sem e-mail
/// (o app não usa esses dados offline, então eles não ficam no aparelho).
String situacaoParaGuardar(Map<String, Object?> s) {
  final perfil = s['perfil'];
  if (perfil is! Map) return jsonEncode(s);
  final limpo = Map<String, Object?>.from(perfil.cast<String, Object?>())
    ..remove('cpf')
    ..remove('email');
  return jsonEncode({...s, 'perfil': limpo});
}

String _json(Map<String, Object?> m) => jsonEncode(m);
Map<String, Object?> _mapa(String t) => (jsonDecode(t) as Map).cast<String, Object?>();

Map<String, Object?> _trocarIdCaminhao(Map<String, Object?> m, String de, String para) {
  if (m['caminhao_id'] == de) return {...m, 'caminhao_id': para};
  return m;
}

class ArmazenamentoDrift implements Armazenamento {
  ArmazenamentoDrift(this.banco);
  final BancoLocal banco;

  @override
  Future<List<Map<String, Object?>>> registros(String tabela) async {
    final linhas = await (banco.select(banco.registros)..where((r) => r.tabela.equals(tabela))).get();
    return [for (final l in linhas) _mapa(l.dados)];
  }

  @override
  Future<Map<String, Object?>?> registro(String tabela, String id) async {
    final l = await (banco.select(banco.registros)..where((r) => r.tabela.equals(tabela) & r.id.equals(id)))
        .getSingleOrNull();
    return l == null ? null : _mapa(l.dados);
  }

  @override
  Future<void> gravarRegistros(String tabela, List<Map<String, Object?>> lista) async {
    if (lista.isEmpty) return;
    await banco.batch((b) {
      b.insertAllOnConflictUpdate(banco.registros, [
        for (final m in lista) RegistrosCompanion.insert(tabela: tabela, id: m['id'].toString(), dados: _json(m)),
      ]);
    });
  }

  @override
  Future<void> apagarRegistro(String tabela, String id) =>
      (banco.delete(banco.registros)..where((r) => r.tabela.equals(tabela) & r.id.equals(id))).go();

  @override
  Future<void> enfileirar(String tabela, String registroId, Map<String, Object?> dados) async {
    await banco.transaction(() async {
      final existente = await (banco.select(banco.filaEnvio)
            ..where((f) => f.tabela.equals(tabela) & f.registroId.equals(registroId) & f.situacao.equals('pendente')))
          .getSingleOrNull();
      // Um item recusado do mesmo registro dá lugar ao novo envio.
      await (banco.delete(banco.filaEnvio)
            ..where((f) => f.tabela.equals(tabela) & f.registroId.equals(registroId) & f.situacao.equals('recusado')))
          .go();
      if (existente == null) {
        await banco.into(banco.filaEnvio).insert(
              FilaEnvioCompanion.insert(tabela: tabela, registroId: registroId, dados: _json(dados)),
            );
      } else {
        await (banco.update(banco.filaEnvio)..where((f) => f.seq.equals(existente.seq))).write(
          FilaEnvioCompanion(dados: Value(_json(dados)), versao: Value(existente.versao + 1)),
        );
      }
    });
  }

  @override
  Future<List<ItemFila>> fila({String? situacao, int limite = 1000}) async {
    final q = banco.select(banco.filaEnvio)
      ..orderBy([(f) => OrderingTerm.asc(f.seq)])
      ..limit(limite);
    if (situacao != null) q.where((f) => f.situacao.equals(situacao));
    final linhas = await q.get();
    return [
      for (final l in linhas)
        ItemFila(
          seq: l.seq,
          tabela: l.tabela,
          registroId: l.registroId,
          dados: _mapa(l.dados),
          versao: l.versao,
          situacao: l.situacao,
          mensagem: l.mensagem,
        ),
    ];
  }

  @override
  Future<void> confirmarEnvio(int seq, int versao) =>
      (banco.delete(banco.filaEnvio)..where((f) => f.seq.equals(seq) & f.versao.equals(versao))).go();

  @override
  Future<void> marcarRecusado(int seq, int versao, String mensagem) =>
      (banco.update(banco.filaEnvio)..where((f) => f.seq.equals(seq) & f.versao.equals(versao)))
          .write(FilaEnvioCompanion(situacao: const Value('recusado'), mensagem: Value(mensagem)));

  @override
  Future<void> removerDaFila(String tabela, String registroId) =>
      (banco.delete(banco.filaEnvio)..where((f) => f.tabela.equals(tabela) & f.registroId.equals(registroId))).go();

  @override
  Future<void> trocarCaminhao(String de, String para) async {
    await banco.transaction(() async {
      final linhas = await banco.select(banco.registros).get();
      for (final l in linhas) {
        final m = _mapa(l.dados);
        if (m['caminhao_id'] == de) {
          await banco.into(banco.registros).insertOnConflictUpdate(
                RegistrosCompanion.insert(tabela: l.tabela, id: l.id, dados: _json(_trocarIdCaminhao(m, de, para))),
              );
        }
      }
      final itens = await banco.select(banco.filaEnvio).get();
      for (final i in itens) {
        final m = _mapa(i.dados);
        if (m['caminhao_id'] == de) {
          await (banco.update(banco.filaEnvio)..where((f) => f.seq.equals(i.seq)))
              .write(FilaEnvioCompanion(dados: Value(_json(_trocarIdCaminhao(m, de, para))), versao: Value(i.versao + 1)));
        }
      }
      await (banco.delete(banco.registros)..where((r) => r.tabela.equals('caminhoes') & r.id.equals(de))).go();
      await (banco.delete(banco.filaEnvio)..where((f) => f.tabela.equals('caminhoes') & f.registroId.equals(de))).go();
    });
  }

  @override
  Future<String?> lerEstado(String chave) async =>
      (await (banco.select(banco.estado)..where((e) => e.chave.equals(chave))).getSingleOrNull())?.valor;

  @override
  Future<void> gravarEstado(String chave, String? valor) =>
      banco.into(banco.estado).insertOnConflictUpdate(EstadoCompanion.insert(chave: chave, valor: Value(valor)));

  @override
  Future<void> limparTudo() async {
    await banco.transaction(() async {
      await banco.delete(banco.registros).go();
      await banco.delete(banco.filaEnvio).go();
      await banco.delete(banco.estado).go();
    });
  }
}

/// Mesma coisa, só na memória (testes).
class ArmazenamentoMemoria implements Armazenamento {
  final _registros = <String, Map<String, Map<String, Object?>>>{};
  final _fila = <ItemFila>[];
  final _estado = <String, String?>{};
  var _seq = 0;

  @override
  Future<List<Map<String, Object?>>> registros(String tabela) async =>
      [for (final m in (_registros[tabela] ?? const {}).values) Map.of(m)];

  @override
  Future<Map<String, Object?>?> registro(String tabela, String id) async {
    final m = _registros[tabela]?[id];
    return m == null ? null : Map.of(m);
  }

  @override
  Future<void> gravarRegistros(String tabela, List<Map<String, Object?>> lista) async {
    final t = _registros.putIfAbsent(tabela, () => {});
    for (final m in lista) {
      t[m['id'].toString()] = Map.of(m);
    }
  }

  @override
  Future<void> apagarRegistro(String tabela, String id) async => _registros[tabela]?.remove(id);

  @override
  Future<void> enfileirar(String tabela, String registroId, Map<String, Object?> dados) async {
    _fila.removeWhere((i) => i.tabela == tabela && i.registroId == registroId && i.situacao == 'recusado');
    final i = _fila.indexWhere((i) => i.tabela == tabela && i.registroId == registroId && i.situacao == 'pendente');
    if (i < 0) {
      _fila.add(ItemFila(
          seq: ++_seq, tabela: tabela, registroId: registroId, dados: Map.of(dados), versao: 1, situacao: 'pendente'));
    } else {
      final a = _fila[i];
      _fila[i] = ItemFila(
          seq: a.seq, tabela: tabela, registroId: registroId, dados: Map.of(dados), versao: a.versao + 1, situacao: 'pendente');
    }
  }

  @override
  Future<List<ItemFila>> fila({String? situacao, int limite = 1000}) async =>
      _fila.where((i) => situacao == null || i.situacao == situacao).take(limite).toList();

  @override
  Future<void> confirmarEnvio(int seq, int versao) async => _fila.removeWhere((i) => i.seq == seq && i.versao == versao);

  @override
  Future<void> marcarRecusado(int seq, int versao, String mensagem) async {
    final i = _fila.indexWhere((i) => i.seq == seq && i.versao == versao);
    if (i < 0) return;
    final a = _fila[i];
    _fila[i] = ItemFila(
        seq: a.seq, tabela: a.tabela, registroId: a.registroId, dados: a.dados, versao: a.versao,
        situacao: 'recusado', mensagem: mensagem);
  }

  @override
  Future<void> removerDaFila(String tabela, String registroId) async =>
      _fila.removeWhere((i) => i.tabela == tabela && i.registroId == registroId);

  @override
  Future<void> trocarCaminhao(String de, String para) async {
    for (final t in _registros.values) {
      for (final id in t.keys.toList()) {
        t[id] = _trocarIdCaminhao(t[id]!, de, para);
      }
    }
    for (var i = 0; i < _fila.length; i++) {
      final a = _fila[i];
      if (a.dados['caminhao_id'] == de) {
        _fila[i] = ItemFila(
            seq: a.seq, tabela: a.tabela, registroId: a.registroId, dados: _trocarIdCaminhao(a.dados, de, para),
            versao: a.versao + 1, situacao: a.situacao, mensagem: a.mensagem);
      }
    }
    _registros['caminhoes']?.remove(de);
    _fila.removeWhere((i) => i.tabela == 'caminhoes' && i.registroId == de);
  }

  @override
  Future<String?> lerEstado(String chave) async => _estado[chave];

  @override
  Future<void> gravarEstado(String chave, String? valor) async => _estado[chave] = valor;

  @override
  Future<void> limparTudo() async {
    _registros.clear();
    _fila.clear();
    _estado.clear();
  }
}
