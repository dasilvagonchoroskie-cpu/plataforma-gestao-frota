import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor/app.dart';
import 'package:gestor/dados/aparelho.dart';
import 'package:gestor/dados/link_email.dart';
import 'package:gestor/dados/provedores.dart';
import 'package:gestor/servidor/servidor.dart';
import 'package:gestor/telas/casca.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart' show versaoTermos;

const empresaId = 'emp-x';
const euDono = 'u-dono';
const euGestor = 'u-gestor';
const joao = 'mot-joao';
const pedro = 'mot-pedro';
const carlos = 'mot-carlos';
const cam1 = 'cam-1';
const cam2 = 'cam-2';
const cam3 = 'cam-3';

DateTime dia(int d, {int hora = 10}) {
  final agora = DateTime.now();
  return DateTime(agora.year, agora.month, d, hora);
}

String iso(DateTime d) => d.toUtc().toIso8601String();

/// Servidor de mentira com o comportamento do banco que o painel usa:
/// tabelas por fonte, ajustes aplicados nas views *_efetivos, decisões de
/// entrada e troca de caminhão. Guarda as chamadas para os testes conferirem.
class ServidorFalso implements Servidor {
  ServidorFalso({this.usuario = euDono});

  String usuario;
  bool sessao = true;
  bool trocarSenha = false;
  bool online = true;
  String? senhaCerta = 'segredo1';
  final chamadas = <String>[];
  final tabelas = <String, List<Map<String, Object?>>>{};
  final pedidos = <Map<String, Object?>>[];
  Map<String, Object?>? perfilDaSessao;

  void _rede() {
    if (!online) throw erroSemInternet;
  }

  List<Map<String, Object?>> t(String fonte) => tabelas.putIfAbsent(fonte, () => []);

  Map<String, Object?> get empresa => t(Fontes.empresa).first;

  @override
  bool get temSessao => sessao;
  @override
  String? get emailDaSessao => usuario == euDono ? 'dono@teste.com' : 'gestor@teste.com';
  @override
  String? get usuarioId => usuario;

  @override
  Future<void> entrar(String email, String senha) async {
    _rede();
    chamadas.add('entrar $email');
    if (senha != senhaCerta) throw const ErroServidor('E-mail ou senha incorretos.', codigo: 'login');
    sessao = true;
  }

  @override
  Future<void> definirSenha(String senha) async {
    chamadas.add('senha');
    trocarSenha = false;
  }

  @override
  bool get precisaTrocarSenha => trocarSenha;

  @override
  Future<Map<String, Object?>> criarAcessoGestor(String email, String nome) async {
    _rede();
    final e = email.trim().toLowerCase();
    chamadas.add('acesso gestor $e');
    if (!t(Fontes.acessos).any((a) => a['email'] == e)) {
      t(Fontes.acessos).add({
        'id': 'ac-${t(Fontes.acessos).length + 1}',
        'empresa_id': empresaId,
        'email': e,
        'papel': 'gestor',
        'ativo': true,
      });
      t(Fontes.perfis).add({'id': 'u-$e', 'nome': nome, 'email': e, 'papel': 'gestor', 'ativo': true});
    }
    return {'ok': true, 'nome': nome, 'email': e, 'senha_provisoria': 'H4QZ8WMP'};
  }

  /// Campos a mais na situação (termos, empresa bloqueada...).
  Map<String, Object?> situacaoExtra = {};
  Map<String, Object?> empresaExtra = {};
  String? termosAceitos;
  String? empresaExcluida;

  /// Super administrador da plataforma e o que ele fez.
  bool admin = false;
  final acoesPlataforma = <String>[];
  final empresasPlataforma = <Map<String, Object?>>[
    {
      'id': 'emp-a', 'nome': 'Transportes Alfa', 'dono_nome': 'Ana Souza', 'dono_email': 'ana@alfa.com',
      'situacao': 'teste', 'acesso_ate': '2026-11-21T12:00:00Z', 'limite_caminhoes': 5, 'motoristas': 3,
      'caminhoes': 2, 'ultimo_envio': null, 'dono_primeiro_acesso_pendente': true,
    },
  ];

  void _admin() {
    if (!admin) {
      throw const ErroServidor('Só o administrador da plataforma pode fazer isso.', codigo: 'sem_permissao');
    }
  }

  @override
  Future<List<Map<String, Object?>>> plataformaEmpresas() async {
    _rede();
    _admin();
    return [...empresasPlataforma];
  }

  @override
  Future<Map<String, Object?>> plataformaCriarEmpresa({
    required String nome,
    required String donoNome,
    required String donoEmail,
    required int? diasTeste,
    required int limiteCaminhoes,
  }) async {
    _rede();
    _admin();
    acoesPlataforma.add('criar $nome $donoNome $donoEmail ${diasTeste ?? 'sem prazo'} $limiteCaminhoes');
    empresasPlataforma.add({
      'id': 'emp-${empresasPlataforma.length}', 'nome': nome, 'dono_nome': donoNome, 'dono_email': donoEmail,
      'situacao': diasTeste == null ? 'liberada' : 'teste', 'limite_caminhoes': limiteCaminhoes,
      'motoristas': 0, 'caminhoes': 0, 'dono_primeiro_acesso_pendente': true,
    });
    return {'nome': nome, 'dono_nome': donoNome, 'dono_email': donoEmail, 'senha_provisoria': 'K7MPQ2RXZ9'};
  }

  @override
  Future<void> plataformaLiberar(String empresaId, {int? dias}) async {
    _rede();
    _admin();
    acoesPlataforma.add('liberar $empresaId ${dias ?? 'sem prazo'}');
  }

  @override
  Future<void> plataformaBloquear(String empresaId, String motivo) async {
    _rede();
    _admin();
    acoesPlataforma.add('bloquear $empresaId $motivo');
  }

  @override
  Future<Map<String, Object?>> plataformaNovaSenhaDono(String empresaId) async {
    _rede();
    _admin();
    acoesPlataforma.add('senha $empresaId');
    return {'dono_nome': 'Ana Souza', 'dono_email': 'ana@alfa.com', 'senha_provisoria': 'W3ZQ8MNP2T'};
  }

  /// Links pedidos por e-mail e links abertos (token_hash válidos).
  final linksPedidos = <String>[];
  final linksValidos = <String>{};
  bool saiuDeTodos = false;

  @override
  Future<Map<String, Object?>> gerarConvite(String nome, String cpf, {String? modalidade}) async {
    _rede();
    chamadas.add('convite $nome $cpf${modalidade == null ? '' : ' $modalidade'}');
    final c = {
      'id': 'conv-${t(Fontes.convites).length + 1}',
      'empresa_id': empresaId,
      'codigo': 'K7M2QX',
      'nome': nome,
      'cpf': cpf,
      'expira_em': iso(DateTime.now().add(const Duration(days: 7))),
      'modalidade': modalidade,
    };
    t(Fontes.convites).add(c);
    return {...c};
  }

  /// Modalidades como o banco devolve (modalidades_da_empresa): só Graneleiro ligado.
  final modalidadesEmpresa = <Map<String, Object?>>[
    for (final (codigo, nome, tipo) in [
      ('graneleiro', 'Graneleiro', 'frete'),
      ('grade_baixa', 'Grade baixa', 'frete'),
      ('cacamba', 'Caçamba', 'frete'),
      ('bau', 'Baú', 'viagem'),
      ('sider', 'Sider', 'viagem'),
    ])
      {
        'codigo': codigo,
        'nome': nome,
        'tipo': tipo,
        'ativa': codigo == 'graneleiro',
        'campos': tipo == 'frete' ? camposFreteTeste : camposViagemTeste,
        'ajustes': <String, Object?>{},
        'motoristas': 0,
      },
  ];

  @override
  Future<List<Map<String, Object?>>> modalidadesDaEmpresa() async {
    _rede();
    return [
      for (final m in modalidadesEmpresa)
        {
          ...m,
          'campos': [
            for (final c in (m['campos'] as List).cast<Map<String, Object?>>())
              {
                ...c,
                ...?((m['ajustes'] as Map)[c['chave']] as Map?)?.cast<String, Object?>(),
              },
          ],
          'motoristas': t(Fontes.motoristas).where((x) => x['modalidade'] == m['codigo'] && x['ativo'] != false).length,
        },
    ];
  }

  void ligarModalidade(String codigo) {
    for (final m in modalidadesEmpresa) {
      if (m['codigo'] == codigo) m['ativa'] = true;
    }
  }

  @override
  Future<void> salvarModalidadeEmpresa(String codigo, bool ativa, {Map<String, Object?>? campos}) async {
    _rede();
    chamadas.add('modalidade $codigo $ativa${campos == null ? '' : ' ${jsonEncode(campos)}'}');
    if (usuario != euDono) {
      throw const ErroServidor('Só o dono muda as modalidades da empresa.', codigo: 'sem_permissao');
    }
    if (!ativa && t(Fontes.motoristas).any((x) => x['modalidade'] == codigo && x['ativo'] != false)) {
      throw const ErroServidor('Há motoristas nesta modalidade. Troque a modalidade deles antes de desligar.');
    }
    for (final m in modalidadesEmpresa) {
      if (m['codigo'] != codigo) continue;
      m['ativa'] = ativa;
      if (campos != null) m['ajustes'] = campos;
    }
  }

  @override
  Future<void> definirModalidadeMotorista(String motoristaId, String codigo) async {
    _rede();
    chamadas.add('modalidade do motorista $motoristaId $codigo');
    for (final m in t(Fontes.motoristas)) {
      if (m['id'] == motoristaId) m['modalidade'] = codigo;
    }
  }

  @override
  Future<Map<String, Object?>> fecharAcerto({
    required String id,
    required String motoristaId,
    required DateTime inicio,
    required DateTime fim,
    required int comissaoCentavos,
    required List<Map<String, Object?>> descontos,
    String? observacao,
  }) async {
    _rede();
    chamadas.add('acerto $motoristaId ${diaIso(inicio)} ${diaIso(fim)} $comissaoCentavos');
    bool noPeriodo(Object? d) {
      final l = DateTime.parse('$d').toLocal();
      final x = DateTime(l.year, l.month, l.day);
      return !x.isBefore(inicio) && !x.isAfter(fim);
    }

    int soma(String fonte, {bool semPartida = false}) => [
      for (final m in t(fonte))
        if (m['motorista_id'] == motoristaId && noPeriodo(m['data']) && !(semPartida && m['ponto_de_partida'] == true))
          lerInt(m['valor_centavos']),
    ].fold(0, (s, v) => s + v);
    final vales = soma(Fontes.vales);
    final diesel = soma(Fontes.abastecimentos, semPartida: true);
    final gastos = soma(Fontes.gastos);
    final regras = Regras.daEmpresa(ConfiguracaoEmpresa.deMapa(empresa));
    final lista = [for (final d in descontos) DescontoAcerto.deMapa(d)];
    final a = {
      'id': id,
      'empresa_id': empresaId,
      'motorista_id': motoristaId,
      'periodo_inicio': diaIso(inicio),
      'periodo_fim': diaIso(fim),
      'comissao_centavos': comissaoCentavos,
      'descontos': descontos,
      'total_descontos_centavos': lista.fold<int>(0, (s, d) => s + d.valorCentavos),
      'vales_centavos': vales,
      'diesel_centavos': diesel,
      'gastos_centavos': gastos,
      'desconta_vales': regras.valeDescontaDoLiquido,
      'desconta_gastos': regras.gastosDescontamDoLiquido,
      'para_receber_centavos': calcularParaReceber(
        comissaoCentavos: comissaoCentavos,
        descontos: lista,
        valesCentavos: vales,
        dieselCentavos: diesel,
        gastosCentavos: gastos,
        regras: regras,
      ),
      'quantidade_viagens': t(Fontes.viagens)
          .where((v) => v['motorista_id'] == motoristaId && noPeriodo(v['engate_em']))
          .length,
      'observacao': observacao,
      'autor_id': usuario,
      'fechado_em': iso(DateTime.now()),
    };
    t(Fontes.acertos)
      ..removeWhere((x) => x['id'] == id)
      ..add(a);
    return {...a};
  }

  /// Catálogo da Plataforma (o super administrador mexe).
  List<Map<String, Object?>> get catalogo => modalidadesEmpresa;

  @override
  Future<List<Map<String, Object?>>> plataformaModalidades() async {
    _rede();
    _admin();
    return [for (final m in catalogo) {...m, 'empresas': m['ativa'] == true ? 1 : 0}];
  }

  @override
  Future<void> plataformaSalvarModalidade({
    required String codigo,
    required String nome,
    required String tipo,
    bool ativa = true,
  }) async {
    _rede();
    _admin();
    acoesPlataforma.add('modalidade $codigo $nome $tipo $ativa');
    final atual = catalogo.where((m) => m['codigo'] == codigo).firstOrNull;
    if (atual != null) {
      atual['nome'] = nome;
      return;
    }
    catalogo.add({
      'codigo': codigo,
      'nome': nome,
      'tipo': tipo,
      'ativa': false,
      'campos': tipo == 'frete' ? [...camposFreteTeste] : [...camposViagemTeste],
      'ajustes': <String, Object?>{},
    });
  }

  @override
  Future<void> plataformaSalvarCampo(String modalidade, Map<String, Object?> campo) async {
    _rede();
    _admin();
    acoesPlataforma.add('campo $modalidade ${jsonEncode(campo)}');
    final m = catalogo.firstWhere((x) => x['codigo'] == modalidade);
    final campos = [...(m['campos'] as List).cast<Map<String, Object?>>()];
    final i = campos.indexWhere((c) => c['chave'] == campo['chave']);
    final novo = {...campo, 'extra': true, 'pode_ocultar': true, 'visivel': campo['desativado'] != true};
    if (i < 0) {
      campos.add(novo);
    } else {
      campos[i] = novo;
    }
    m['campos'] = campos;
  }

  @override
  Future<void> cancelarConvite(String conviteId) async {
    _rede();
    chamadas.add('cancelar convite $conviteId');
    for (final c in t(Fontes.convites)) {
      if (c['id'] == conviteId) c['cancelado_em'] = iso(DateTime.now());
    }
  }

  @override
  Future<void> excluirMotorista(String motoristaId) async {
    _rede();
    chamadas.add('excluir motorista $motoristaId');
    t(Fontes.motoristas).removeWhere((m) => m['id'] == motoristaId);
    for (final f in [Fontes.fretes, Fontes.abastecimentos, Fontes.gastos, Fontes.vales, Fontes.usos, Fontes.ajustesKm]) {
      t(f).removeWhere((m) => m['motorista_id'] == motoristaId);
    }
  }

  @override
  Future<void> excluirMinhaEmpresa(String confirmacao) async {
    _rede();
    chamadas.add('excluir empresa $confirmacao');
    empresaExcluida = confirmacao;
  }

  @override
  Future<Map<String, Object?>> aceitarTermos(String versao) async {
    _rede();
    termosAceitos = versao;
    situacaoExtra = {...situacaoExtra, 'termos': {'versao': versao, 'aceito': true}};
    return situacao();
  }

  @override
  Future<String> pedirLinkSenha(String email) async {
    _rede();
    linksPedidos.add(email);
    return 'Se este e-mail tiver conta, mandamos um link para ele.';
  }

  @override
  Future<void> abrirLinkDoEmail(String tokenHash, {required bool senha}) async {
    _rede();
    if (!linksValidos.remove(tokenHash)) {
      throw const ErroServidor('Este link venceu ou já foi usado. Peça outro em "Esqueci a senha".');
    }
    chamadas.add(senha ? 'link senha' : 'link email');
    sessao = true;
  }

  @override
  Future<void> registrarAcesso(String app) async => chamadas.add('acesso $app');

  @override
  Future<Map<String, Object?>> completarCadastro(String nome) async {
    chamadas.add('cadastro $nome');
    return situacao();
  }


  @override
  Future<Map<String, Object?>> situacao() async {
    _rede();
    if (!sessao) return {'logado': false};
    final p = t(Fontes.perfis).firstWhere((p) => p['id'] == usuario, orElse: () => const {});
    return {
      'logado': true,
      'perfil': perfilDaSessao ?? (p.isEmpty ? null : p),
      'empresa': {...empresa, ...empresaExtra},
      'motorista': null,
      'pedido': null,
      'admin_plataforma': admin,
      ...situacaoExtra,
    };
  }

  @override
  Future<Map<String, List<Map<String, Object?>>>> carregar() async {
    _rede();
    return {
      for (final f in Fontes.todas) f: [for (final m in t(f)) Map<String, Object?>.from(m)],
    };
  }

  @override
  Future<List<Map<String, Object?>>> pedidosEntrada() async => [
    for (final p in pedidos) {...p},
  ];

  @override
  Future<void> decidirEntrada(String pedidoId, bool aprovar) async {
    _rede();
    chamadas.add('decidir $pedidoId $aprovar');
    final p = pedidos.firstWhere((p) => p['id'] == pedidoId);
    p['status'] = aprovar ? 'aprovado' : 'recusado';
    p['decidido_em'] = iso(DateTime.now());
    if (aprovar) {
      t(Fontes.motoristas).add({
        'id': 'mot-${p['perfil_id']}',
        'empresa_id': empresaId,
        'perfil_id': p['perfil_id'],
        'nome': p['nome'],
        'cpf': p['cpf'],
        'email': p['email'],
        'ativo': true,
      });
    }
  }

  @override
  Future<String> gerarNovoCodigo() async {
    chamadas.add('novo codigo');
    empresa['codigo_entrada'] = 'NOVO23';
    return 'NOVO23';
  }

  @override
  Future<void> definirCaminhaoAtual(String motoristaId, String caminhaoId) async {
    chamadas.add('caminhao $motoristaId $caminhaoId');
    final agora = iso(DateTime.now());
    for (final u in t(Fontes.usos)) {
      if (u['motorista_id'] == motoristaId && u['fim_em'] == null) u['fim_em'] = agora;
    }
    t(Fontes.usos).add({
      'id': 'uso-${t(Fontes.usos).length + 1}',
      'empresa_id': empresaId,
      'motorista_id': motoristaId,
      'caminhao_id': caminhaoId,
      'inicio_em': agora,
    });
  }

  @override
  Future<Map<String, Object?>> redefinirAcesso(String motoristaId) async {
    chamadas.add('redefinir $motoristaId');
    return {'ok': true, 'nome': 'João', 'senha_provisoria': 'K7PX3MQA'};
  }

  static const _views = {
    'fretes': Fontes.fretes,
    'abastecimentos': Fontes.abastecimentos,
    'gastos_viagem': Fontes.gastos,
    'vales': Fontes.vales,
  };

  @override
  Future<void> inserir(String tabela, Map<String, Object?> dados) async {
    _rede();
    chamadas.add('inserir $tabela');
    if (tabela == 'caminhoes' && t(Fontes.caminhoes).any((c) => c['placa'] == dados['placa'])) {
      throw const ErroServidor('Já existe um cadastro igual a este.', codigo: 'repetido');
    }
    if (tabela == 'ajustes_gestor') {
      final view = t(_views[dados['tabela_alvo']]!);
      final linha = view.firstWhere((m) => m['id'] == dados['registro_id']);
      final campo = dados['campo'] as String;
      final anterior = linha[campo];
      linha[campo] = dados['valor_novo'];
      linha['campos_ajustados'] = {...lerLista(linha['campos_ajustados']), campo}.toList()..sort();
      t(Fontes.ajustes).add({...dados, 'valor_antigo': anterior, 'criado_em': iso(DateTime.now())});
      return;
    }
    t(tabela).add({...dados, 'criado_em': iso(DateTime.now())});
  }

  @override
  Future<void> alterar(String tabela, String id, Map<String, Object?> campos) async {
    _rede();
    chamadas.add('alterar $tabela $id ${campos.keys.join(',')}');
    final linha = t(tabela).firstWhere((m) => m['id'] == id);
    linha.addAll(campos);
  }

  @override
  Future<void> sair({bool todosOsAparelhos = false}) async {
    chamadas.add('sair');
    saiuDeTodos = saiuDeTodos || todosOsAparelhos;
    sessao = false;
  }
}

/// Uma empresa com dois motoristas trabalhando, um desligado, três
/// caminhões (um cadastrado por motorista), um mês de lançamentos e um
/// pedido de entrada esperando.
ServidorFalso servidorComAmostra({String usuario = euDono}) {
  final s = ServidorFalso(usuario: usuario);
  final agora = DateTime.now();
  s.t(Fontes.empresa).add({
    'id': empresaId,
    'empresa_id': empresaId,
    'nome': 'Transportes Goiatuba',
    'documento': '12.345.678/0001-90',
    'codigo_entrada': 'K7P3XM',
    'plano': 'piloto',
    'limite_caminhoes': 5,
    'status': 'teste',
    'percentual_comissao_padrao': 13,
    'comissao_sobre_bruto_padrao': false,
    'gastos_descontam_do_liquido': false,
    'vale_desconta_do_liquido': true,
  });
  s.t(Fontes.perfis).addAll([
    {'id': euDono, 'nome': 'Evandro Dono', 'email': 'dono@teste.com', 'papel': 'dono', 'ativo': true},
    {'id': euGestor, 'nome': 'Marta Gestora', 'email': 'gestor@teste.com', 'papel': 'gestor', 'ativo': true},
    {'id': 'u-joao', 'nome': 'João Batista', 'email': 'joao@teste.com', 'papel': 'motorista', 'ativo': true},
    {'id': 'u-pedro', 'nome': 'Pedro Henrique', 'email': 'pedro@teste.com', 'papel': 'motorista', 'ativo': true},
  ]);
  s.t(Fontes.acessos).addAll([
    {'id': 'ac-1', 'empresa_id': empresaId, 'email': 'dono@teste.com', 'papel': 'dono', 'ativo': true},
    {'id': 'ac-2', 'empresa_id': empresaId, 'email': 'gestor@teste.com', 'papel': 'gestor', 'ativo': true},
  ]);
  s.t(Fontes.motoristas).addAll([
    {
      'id': joao,
      'empresa_id': empresaId,
      'perfil_id': 'u-joao',
      'nome': 'João Batista',
      'cpf': '11144477735',
      'email': 'joao@teste.com',
      'ativo': true,
    },
    {
      'id': pedro,
      'empresa_id': empresaId,
      'perfil_id': 'u-pedro',
      'nome': 'Pedro Henrique',
      'cpf': '39053344705',
      'email': 'pedro@teste.com',
      'ativo': true,
    },
    {
      'id': carlos,
      'empresa_id': empresaId,
      'perfil_id': 'u-carlos',
      'nome': 'Carlos Souza',
      'cpf': '15350946056',
      'email': 'carlos@teste.com',
      'ativo': false,
    },
  ]);
  s.t(Fontes.caminhoes).addAll([
    const Caminhao(id: cam1, placa: 'RVG2C47', numeroFrota: '07', modelo: 'Scania R450', ano: 2021).paraMapa(),
    const Caminhao(id: cam2, placa: 'DEF4567', numeroFrota: '12', modelo: 'Volvo FH 540').paraMapa(),
    const Caminhao(id: cam3, placa: 'QWE1A23', confirmado: false).paraMapa(),
  ]);
  s.t(Fontes.categorias).addAll([
    for (final n in ['Borracharia', 'Chapa', 'Lavagem', 'Pedágio'])
      {'id': 'cat-$n', 'empresa_id': empresaId, 'nome': n, 'ativa': true},
  ]);
  s.t(Fontes.usos).addAll([
    {
      'id': 'uso-1',
      'motorista_id': joao,
      'caminhao_id': cam1,
      'inicio_em': iso(agora.subtract(const Duration(days: 60))),
    },
    {
      'id': 'uso-2',
      'motorista_id': pedro,
      'caminhao_id': cam2,
      'inicio_em': iso(agora.subtract(const Duration(days: 40))),
    },
  ]);
  s.t(Fontes.dispositivos).addAll([
    {
      'id': 'disp-1',
      'perfil_id': 'u-joao',
      'apelido': 'Samsung A15',
      'ultimo_sync_em': iso(agora.subtract(const Duration(hours: 2))),
    },
    {
      'id': 'disp-2',
      'perfil_id': 'u-pedro',
      'apelido': 'Motorola G54',
      'ultimo_sync_em': iso(agora.subtract(const Duration(days: 5))),
    },
  ]);
  Map<String, Object?> comCampos(Map<String, Object?> m) => {...m, 'campos_ajustados': <String>[]};
  s.t(Fontes.fretes).addAll([
    comCampos(
      Frete(
        id: 'f1',
        motoristaId: joao,
        caminhaoId: cam1,
        origem: 'Jataí (GO)',
        destino: 'Paranaguá (PR)',
        embarcador: 'Cerealista Cerrado',
        dataCarga: dia(2),
        pesoCargaKg: 37000,
        valorToneladaCentavos: 21000,
        adiantamentoCentavos: 540000,
        saldoCentavos: 225000,
        pedagioCentavos: 69000,
        percentualComissao: 13,
        criadoNoAparelhoEm: dia(2, hora: 11),
      ).paraMapa(),
    ),
    comCampos(
      Frete(
        id: 'f2',
        motoristaId: joao,
        caminhaoId: cam1,
        origem: 'Paranaguá (PR)',
        destino: 'Rio Verde (GO)',
        embarcador: 'Fertilizantes Sul',
        dataCarga: dia(6),
        pesoCargaKg: 32000,
        valorToneladaCentavos: 16500,
        adiantamentoCentavos: 380000,
        percentualComissao: 13,
      ).paraMapa(),
    ),
    comCampos(
      Frete(
        id: 'f3',
        motoristaId: pedro,
        caminhaoId: cam2,
        origem: 'Goiatuba (GO)',
        destino: 'Santos (SP)',
        embarcador: 'Cerealista Cerrado',
        dataCarga: dia(3),
        pesoCargaKg: 36500,
        valorToneladaCentavos: 19500,
        adiantamentoCentavos: 500000,
        saldoCentavos: 205000,
        percentualComissao: 12,
        pesoDescargaKg: 36420,
        descontoQuebraCentavos: 1600,
      ).paraMapa(),
    ),
  ]);
  s.t(Fontes.abastecimentos).addAll([
    comCampos(
      Abastecimento(
        id: 'p0',
        motoristaId: joao,
        caminhaoId: cam1,
        data: dia(1),
        kmOdometro: 412000,
        pontoDePartida: true,
      ).paraMapa(),
    ),
    comCampos(
      Abastecimento(
        id: 'a1',
        motoristaId: joao,
        caminhaoId: cam1,
        data: dia(3),
        kmOdometro: 412950,
        litros: 380,
        valorCentavos: 228000,
        cidade: 'Maringá',
        posto: 'Posto Trevo',
      ).paraMapa(),
    ),
    comCampos(
      Abastecimento(
        id: 'a2',
        motoristaId: joao,
        caminhaoId: cam1,
        data: dia(7),
        kmOdometro: 413900,
        litros: 365.5,
        valorCentavos: 219300,
        cidade: 'Campo Grande',
        posto: 'Graal',
      ).paraMapa(),
    ),
    comCampos(
      Abastecimento(
        id: 'p1',
        motoristaId: pedro,
        caminhaoId: cam2,
        data: dia(1),
        kmOdometro: 288000,
        pontoDePartida: true,
      ).paraMapa(),
    ),
    comCampos(
      Abastecimento(
        id: 'a3',
        motoristaId: pedro,
        caminhaoId: cam2,
        data: dia(4),
        kmOdometro: 288780,
        litros: 330,
        valorCentavos: 196000,
        cidade: 'Uberlândia',
        posto: 'Posto Rodoviária',
      ).paraMapa(),
    ),
  ]);
  s.t(Fontes.gastos).addAll([
    comCampos(
      Gasto(
        id: 'g1',
        motoristaId: joao,
        caminhaoId: cam1,
        data: dia(4),
        categoriaId: 'cat-Borracharia',
        valorCentavos: 8000,
      ).paraMapa(),
    ),
    comCampos(
      Gasto(
        id: 'g2',
        motoristaId: pedro,
        caminhaoId: cam2,
        data: dia(5),
        categoriaId: 'cat-Chapa',
        valorCentavos: 25000,
        observacao: 'Descarga em Santos',
      ).paraMapa(),
    ),
  ]);
  s.t(Fontes.vales).addAll([
    comCampos(
      Vale(id: 'v1', motoristaId: joao, data: dia(4), valorCentavos: 50000, observacao: 'Adiantamento').paraMapa(),
    ),
  ]);
  s.pedidos.add({
    'id': 'ped-1',
    'status': 'pendente',
    'pedido_em': iso(agora.subtract(const Duration(hours: 3))),
    'perfil_id': 'u-marcos',
    'nome': 'Marcos Vinícius',
    'cpf': '52998224725',
    'email': 'marcos@teste.com',
  });
  return s;
}

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

/// Abre o app inteiro com o servidor falso, no tamanho pedido.
Future<void> abrirApp(
  WidgetTester tester,
  ServidorFalso s, {
  Size tela = const Size(1280, 860),
  double densidade = 1,
  Widget? inicio,
  bool termosAceitosNoAparelho = true,
  LinkDoEmail? link,
}) async {
  tester.view.physicalSize = tela * densidade;
  tester.view.devicePixelRatio = densidade;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        servidorProvider.overrideWithValue(s),
        atualizarSozinhoProvider.overrideWithValue(false),
        aparelhoProvider.overrideWithValue(
          AparelhoMemoria({if (termosAceitosNoAparelho) chaveTermosAparelho: versaoTermos}),
        ),
        linkDoEmailProvider.overrideWith(() => LinkAberto(link)),
      ],
      child: AplicativoGestor(inicio: inicio),
    ),
  );
  await tester.pumpAndSettle();
}

/// Tamanho de um celular comum (em pontos).
const celular = Size(392, 850);

/// Campos de fábrica (como o banco manda, já com visivel e obrigatorio).
const camposFreteTeste = <Map<String, Object?>>[
  {'chave': 'data_carga', 'rotulo': 'Data da carga', 'tipo': 'data', 'obrigatorio': true, 'pode_ocultar': false, 'visivel': true},
  {'chave': 'origem', 'rotulo': 'Origem (de onde saiu)', 'tipo': 'cidade', 'obrigatorio': true, 'pode_ocultar': false, 'visivel': true},
  {'chave': 'destino', 'rotulo': 'Destino (para onde vai)', 'tipo': 'cidade', 'obrigatorio': true, 'pode_ocultar': false, 'visivel': true},
  {'chave': 'embarcador', 'rotulo': 'Embarcador ou cliente', 'tipo': 'texto', 'obrigatorio': false, 'pode_ocultar': true, 'visivel': true},
  {'chave': 'saldo_centavos', 'rotulo': 'Saldo', 'tipo': 'dinheiro', 'obrigatorio': false, 'pode_ocultar': true, 'visivel': true},
];

const camposViagemTeste = <Map<String, Object?>>[
  {'chave': 'placa_carreta', 'rotulo': 'Placa da carreta', 'tipo': 'placa', 'obrigatorio': true, 'pode_ocultar': false, 'visivel': true, 'etapa': 'engate'},
  {'chave': 'engate_local', 'rotulo': 'Onde engatou', 'tipo': 'cidade', 'obrigatorio': true, 'pode_ocultar': false, 'visivel': true, 'etapa': 'engate'},
  {'chave': 'entregas_cidades', 'rotulo': 'Cidades das entregas', 'tipo': 'cidades', 'obrigatorio': false, 'pode_ocultar': true, 'visivel': true, 'etapa': 'entregas'},
  {'chave': 'observacao', 'rotulo': 'Observação', 'tipo': 'texto', 'obrigatorio': false, 'pode_ocultar': true, 'visivel': true, 'etapa': 'desengate'},
];
