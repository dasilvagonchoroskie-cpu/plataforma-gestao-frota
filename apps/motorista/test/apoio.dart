import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorista/dados/armazenamento.dart';
import 'package:motorista/dados/dados.dart';
import 'package:motorista/servidor/servidor.dart';

const motoristaA = 'mot-a';
const motoristaB = 'mot-b';
const caminhao1 = 'cam-1';
const caminhao2 = 'cam-2';
const categoria = 'cat-borracharia';

Map<String, Object?> situacaoDe(String motoristaId, {String nome = 'João da Silva', bool ativo = true, String status = 'ativa'}) => {
      'logado': true,
      'perfil': {'id': 'u-$motoristaId', 'nome': nome, 'papel': 'motorista', 'ativo': true},
      'empresa': {
        'id': 'emp-x',
        'nome': 'Transportes Goiatuba',
        'status': status,
        'percentual_comissao_padrao': 13,
        'comissao_sobre_bruto_padrao': false,
        'gastos_descontam_do_liquido': false,
        'vale_desconta_do_liquido': true,
      },
      'motorista': {'id': motoristaId, 'nome': nome, 'ativo': ativo},
      'pedido': null,
    };

/// Servidor de mentira que se comporta como sincronizar_lote/baixar_alteracoes
/// do banco: upsert pelo id, sem duplicar, cada motorista só vê o que é dele.
class ServidorFalso implements Servidor {
  ServidorFalso({this.motoristaId = motoristaA});

  String motoristaId;
  bool online = true;
  bool sessao = true;
  bool trocarSenha = false;

  /// Grava o lote mas "perde" a resposta (internet caiu no meio).
  bool perderResposta = false;
  int lotesRecebidos = 0;

  /// O que existe na nuvem: tabela -> id -> dados.
  final nuvem = <String, Map<String, Map<String, Object?>>>{};
  final ajustes = <Map<String, Object?>>[];
  final placasDoGestor = <String, String>{}; // placa -> id do caminhão do gestor
  var relogio = DateTime.utc(2026, 10, 15, 12);

  /// Situação fixa (cadastro novo, sem empresa); nula = motorista aprovado.
  Map<String, Object?>? situacaoFixa;
  final cadastros = <String>[];

  Map<String, Object?> situacaoAtual() => situacaoFixa ?? situacaoDe(motoristaId);

  void _rede() {
    if (!online) throw const ErroServidor('Sem internet agora.', semInternet: true);
  }

  void colocar(String tabela, Map<String, Object?> dados) =>
      nuvem.putIfAbsent(tabela, () => {})[dados['id'].toString()] = {...dados, 'atualizado_em': relogio.toIso8601String()};

  @override
  bool get temSessao => sessao;

  @override
  String? get emailDaSessao => 'motorista@teste.com';

  @override
  bool get precisaTrocarSenha => trocarSenha;

  /// E-mail do motorista: confirmado e esperando confirmação.
  String? emailConfirmadoNaNuvem = 'motorista@teste.com';
  String? emailEsperandoNaNuvem;
  final emailsCadastrados = <String>[];
  final linksPedidos = <String>[];

  @override
  String? get emailConfirmado => emailConfirmadoNaNuvem;

  @override
  String? get emailEsperando => emailEsperandoNaNuvem;

  @override
  Future<String> pedirLinkSenha(String cpf) async {
    _rede();
    linksPedidos.add(cpf);
    return 'Se este CPF tiver um e-mail confirmado, mandamos um link para ele.';
  }

  @override
  Future<void> cadastrarEmail(String email) async {
    _rede();
    emailsCadastrados.add(email);
    emailEsperandoNaNuvem = email;
  }

  @override
  Future<void> atualizarConta() async {}

  @override
  Future<Map<String, Object?>> sincronizarLote(Map<String, Object?> lote) async {
    _rede();
    lotesRecebidos++;
    final aceitos = <Map<String, Object?>>[];
    final rejeitados = <Map<String, Object?>>[];
    final mapa = <String, String>{};
    for (final i in (lote['itens'] as List).cast<Map<String, Object?>>()) {
      final tabela = i['tabela'] as String;
      var dados = Map<String, Object?>.from(i['dados'] as Map);
      final id = dados['id'] as String;
      if (dados['caminhao_id'] != null && mapa.containsKey(dados['caminhao_id'])) {
        dados['caminhao_id'] = mapa[dados['caminhao_id']];
      }
      if (tabela == 'caminhoes') {
        final doGestor = placasDoGestor[dados['placa']];
        if (doGestor != null) {
          mapa[id] = doGestor;
          aceitos.add({'tabela': tabela, 'id': id, 'substituido_por': doGestor,
            'atual': {'id': doGestor, 'placa': dados['placa'], 'ativo': true, 'confirmado': true}});
          continue;
        }
        colocar(tabela, dados);
        aceitos.add({'tabela': tabela, 'id': id});
        continue;
      }
      final existente = nuvem[tabela]?[id];
      if (existente != null && existente['motorista_id'] != motoristaId) {
        rejeitados.add({'tabela': tabela, 'id': id, 'motivo': 'id_em_uso', 'mensagem': 'Registro repetido.'});
        continue;
      }
      if (existente != null && ajustes.any((a) => a['registro_id'] == id)) {
        final igual = dados.entries.every((e) => e.key == 'apagado_em' || existente[e.key] == e.value);
        if (!igual) {
          rejeitados.add({
            'tabela': tabela, 'id': id, 'motivo': 'ajustado',
            'mensagem': 'O seu patrão já corrigiu este lançamento. Para mudar de novo, fale com ele.',
            'atual': existente,
          });
          continue;
        }
      }
      dados = {...dados, 'motorista_id': motoristaId};
      colocar(tabela, dados);
      aceitos.add({'tabela': tabela, 'id': id});
    }
    if (perderResposta) {
      perderResposta = false;
      throw const ErroServidor('Sem internet agora.', semInternet: true);
    }
    return {'aceitos': aceitos, 'rejeitados': rejeitados, 'suspensa': false, 'servidor_em': relogio.toIso8601String()};
  }

  @override
  Future<Map<String, Object?>> baixarAlteracoes(DateTime? desde) async {
    _rede();
    bool novo(Map<String, Object?> m) =>
        desde == null || DateTime.parse(m['atualizado_em'] as String).isAfter(desde.subtract(const Duration(minutes: 2)));
    List<Map<String, Object?>> de(String t, {bool soMeus = true}) => [
          for (final m in (nuvem[t] ?? const {}).values)
            if ((!soMeus || m['motorista_id'] == motoristaId) && novo(m)) m,
        ];
    return {
      'servidor_em': relogio.toIso8601String(),
      'situacao': situacaoAtual(),
      'caminhoes': de('caminhoes', soMeus: false),
      'categorias': de('categorias_gasto', soMeus: false),
      'fretes': de('fretes'),
      'abastecimentos': de('abastecimentos'),
      'gastos_viagem': de('gastos_viagem'),
      'vales': de('vales'),
      'ajustes_km': de('ajustes_km'),
      'uso_caminhao': de('uso_caminhao'),
      'ajustes': [...ajustes],
    };
  }

  @override
  Future<Map<String, Object?>> situacao() async {
    _rede();
    return situacaoAtual();
  }

  @override
  Future<void> pedirCodigoCadastro(String email) async => _rede();
  @override
  Future<void> confirmarCodigoCadastro(String email, String codigo) async => _rede();
  @override
  Future<void> definirSenha(String senha) async => _rede();
  @override
  Future<Map<String, Object?>> completarCadastro(String nome, String cpf) async => situacaoAtual();
  @override
  Future<void> entrarComCpf(String cpf, String senha, String aparelho) async {
    _rede();
    sessao = true;
  }

  @override
  Future<void> cadastrarMotorista(String nome, String cpf, String senha, String aparelho, {String? termos}) async {
    _rede();
    if (cadastros.contains(cpf)) {
      throw const ErroServidor('Este CPF já tem cadastro. Entre com CPF e senha.', codigo: 'cpf_em_uso');
    }
    cadastros.add(cpf);
    termosAceitos = termos;
  }

  String? termosAceitos;
  int acessosRegistrados = 0;
  bool contaExcluida = false;

  @override
  Future<Map<String, Object?>> aceitarTermos(String versao) async {
    _rede();
    termosAceitos = versao;
    final s = situacaoFixa;
    if (s != null) situacaoFixa = {...s, 'termos': {'versao': versao, 'aceito': true}};
    return situacaoAtual();
  }

  @override
  Future<Map<String, Object?>> excluirMinhaConta() async {
    _rede();
    contaExcluida = true;
    return {'ok': true, 'apagada': situacaoAtual()['motorista'] == null};
  }

  @override
  Future<void> registrarAcesso() async => acessosRegistrados++;

  @override
  Future<Map<String, Object?>> pedirEntrada(String codigo) async => {'ok': true, 'status': 'pendente'};
  @override
  Future<void> sair() async => sessao = false;
}

/// Nuvem com dois caminhões e as categorias da empresa.
ServidorFalso servidorComCadastros({String motoristaId = motoristaA}) {
  final s = ServidorFalso(motoristaId: motoristaId);
  s.colocar('caminhoes', {'id': caminhao1, 'placa': 'ABC1D23', 'numero_frota': '01', 'ativo': true, 'confirmado': true});
  s.colocar('caminhoes', {'id': caminhao2, 'placa': 'DEF4567', 'numero_frota': '02', 'ativo': true, 'confirmado': true});
  s.colocar('categorias_gasto', {'id': categoria, 'nome': 'Borracharia', 'ativa': true});
  return s;
}

/// Celular já aprovado, com os cadastros baixados.
Future<ProviderContainer> celular(ServidorFalso servidor, {Armazenamento? armazenamento, DateTime? agora}) async {
  final a = armazenamento ?? ArmazenamentoMemoria();
  await a.gravarEstado('situacao', jsonEncode(servidor.situacaoAtual()));
  await a.gravarEstado('pronto', '1');
  final c = ProviderContainer(overrides: [
    armazenamentoProvider.overrideWithValue(a),
    servidorProvider.overrideWithValue(servidor),
    if (agora != null) relogioProvider.overrideWithValue(() => agora),
  ]);
  await c.read(dadosProvider.future);
  return c;
}
