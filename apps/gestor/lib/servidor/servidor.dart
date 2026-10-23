import 'dart:async';

import 'package:nucleo/nucleo.dart' show diaIso;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Erro já com a mensagem em português simples para mostrar na tela.
class ErroServidor implements Exception {
  const ErroServidor(this.mensagem, {this.codigo = '', this.semInternet = false});
  final String mensagem;
  final String codigo;
  final bool semInternet;

  @override
  String toString() => mensagem;
}

const erroSemInternet = ErroServidor('Sem internet agora. Confira a conexão e tente de novo.', semInternet: true);

/// Tabelas e views que o painel lê. Lançamentos vêm das views *_efetivos
/// (valor original com as correções do gestor aplicadas).
class Fontes {
  static const empresa = 'empresas';
  static const perfis = 'perfis';
  static const motoristas = 'motoristas';
  static const caminhoes = 'caminhoes';
  static const categorias = 'categorias_gasto';
  static const fretes = 'fretes_efetivos';
  static const abastecimentos = 'abastecimentos_efetivos';
  static const gastos = 'gastos_viagem_efetivos';
  static const vales = 'vales_efetivos';
  static const ajustesKm = 'ajustes_km';
  static const usos = 'uso_caminhao';
  static const ajustes = 'ajustes_gestor';
  static const dispositivos = 'dispositivos';
  static const acessos = 'acessos_autorizados';
  static const convites = 'convites_motorista';
  static const viagens = 'viagens';
  static const acertos = 'acertos';

  static const todas = [
    empresa,
    perfis,
    motoristas,
    caminhoes,
    categorias,
    fretes,
    abastecimentos,
    gastos,
    vales,
    ajustesKm,
    usos,
    ajustes,
    dispositivos,
    acessos,
    convites,
    viagens,
    acertos,
  ];
}

/// Tudo que o painel conversa com a nuvem. Nos testes entra uma versão falsa.
abstract class Servidor {
  bool get temSessao;
  String? get emailDaSessao;
  String? get usuarioId;

  /// Entrou com senha provisória (criada pelo dono ou pela plataforma).
  bool get precisaTrocarSenha;

  Future<void> entrar(String email, String senha);
  Future<void> definirSenha(String senha);
  Future<Map<String, Object?>> completarCadastro(String nome);

  /// Pede o link para criar a senha nova (vai por e-mail). Devolve o recado.
  Future<String> pedirLinkSenha(String email);

  /// Abre o link que chegou por e-mail ([senha]: criar senha nova; senão,
  /// confirmar o e-mail). Deixa a pessoa logada para o próximo passo.
  Future<void> abrirLinkDoEmail(String tokenHash, {required bool senha});
  Future<Map<String, Object?>> situacao();

  /// Todas as linhas de cada fonte (Fontes.todas) que o RLS deixa ver.
  Future<Map<String, List<Map<String, Object?>>>> carregar();
  Future<List<Map<String, Object?>>> pedidosEntrada();
  Future<void> decidirEntrada(String pedidoId, bool aprovar);
  Future<String> gerarNovoCodigo();
  Future<void> definirCaminhaoAtual(String motoristaId, String caminhaoId);
  Future<Map<String, Object?>> redefinirAcesso(String motoristaId);

  /// O dono cria ou renova o acesso de um gestor (senha provisória, sem e-mail).
  Future<Map<String, Object?>> criarAcessoGestor(String email, String nome);

  /// Cadastra o motorista (nome e CPF) e devolve o código individual dele.
  /// [modalidade]: a do motorista (quando a empresa tem mais de uma).
  Future<Map<String, Object?>> gerarConvite(String nome, String cpf, {String? modalidade});

  /// Modalidades do catálogo com a situação na empresa, os ajustes do dono e
  /// quantos motoristas usam cada uma.
  Future<List<Map<String, Object?>>> modalidadesDaEmpresa();

  /// O dono liga ou desliga uma modalidade e ajusta os campos ([campos] nulo = não mexe).
  Future<void> salvarModalidadeEmpresa(String codigo, bool ativa, {Map<String, Object?>? campos});

  /// O gestor define a modalidade de um motorista.
  Future<void> definirModalidadeMotorista(String motoristaId, String codigo);

  /// Fecha (ou corrige) o acerto de um motorista. Devolve o acerto gravado.
  Future<Map<String, Object?>> fecharAcerto({
    required String id,
    required String motoristaId,
    required DateTime inicio,
    required DateTime fim,
    required int comissaoCentavos,
    required List<Map<String, Object?>> descontos,
    String? observacao,
  });
  Future<void> cancelarConvite(String conviteId);

  /// Exclui o motorista e todos os lançamentos dele.
  Future<void> excluirMotorista(String motoristaId);

  /// O dono exclui a empresa e todos os dados ([confirmacao] = nome da empresa).
  Future<void> excluirMinhaEmpresa(String confirmacao);

  /// Aceite dos Termos de Uso e da Política de Privacidade.
  Future<Map<String, Object?>> aceitarTermos(String versao);

  /// Registro de acesso (data, hora e IP) exigido pelo Marco Civil.
  Future<void> registrarAcesso(String app);

  /// Inclui uma linha (caminhões, categorias, acessos e ajustes).
  Future<void> inserir(String tabela, Map<String, Object?> dados);

  /// Muda colunas de uma linha (só as que o banco libera para cada perfil).
  Future<void> alterar(String tabela, String id, Map<String, Object?> campos);

  // Área da Plataforma (só o super administrador; o banco confere em cada ação).

  /// Todas as empresas, com o dono, a situação e o uso.
  Future<List<Map<String, Object?>>> plataformaEmpresas();

  /// Cadastra a empresa e o dono; devolve a senha provisória (mostrada uma vez).
  Future<Map<String, Object?>> plataformaCriarEmpresa({
    required String nome,
    required String donoNome,
    required String donoEmail,
    required int? diasTeste,
    required int limiteCaminhoes,
  });

  /// Libera a empresa por [dias] a partir de agora (nulo = sem prazo).
  Future<void> plataformaLiberar(String empresaId, {int? dias});
  Future<void> plataformaBloquear(String empresaId, String motivo);

  /// Senha provisória nova para o dono (perdeu o acesso ao e-mail).
  Future<Map<String, Object?>> plataformaNovaSenhaDono(String empresaId);

  /// Catálogo de modalidades (todas, com os campos de fábrica e os novos).
  Future<List<Map<String, Object?>>> plataformaModalidades();

  /// Cria uma modalidade nova ou muda nome e situação de uma que existe.
  Future<void> plataformaSalvarModalidade({
    required String codigo,
    required String nome,
    required String tipo,
    bool ativa = true,
  });

  /// Cria ou muda um campo novo de uma modalidade.
  Future<void> plataformaSalvarCampo(String modalidade, Map<String, Object?> campo);

  /// Sai da conta. Com [todosOsAparelhos], encerra também as outras sessões
  /// (depois de criar a senha nova pelo link).
  Future<void> sair({bool todosOsAparelhos = false});
}

bool _pareceSemInternet(String texto) {
  const sinais = [
    'SocketException',
    'ClientException',
    'Failed host lookup',
    'Connection refused',
    'Network is unreachable',
    'Failed to fetch',
    'XMLHttpRequest',
    'NetworkError',
    'Connection closed',
    'TimeoutException',
  ];
  return sinais.any(texto.contains);
}

ErroServidor traduzirErro(Object e) {
  if (e is ErroServidor) return e;
  if (e is TimeoutException) return erroSemInternet;
  final texto = e.toString();
  if (e is PostgrestException) {
    // As funções do banco já devolvem a frase pronta (e um código no hint).
    final codigo = e.hint ?? '';
    if (e.code == 'PGRST301' || e.code == '401' || texto.contains('JWT')) {
      return const ErroServidor('Sua entrada venceu. Entre de novo.', codigo: 'sessao');
    }
    if (codigo.isNotEmpty) return ErroServidor(e.message, codigo: codigo);
    if (e.code == '23505') {
      return const ErroServidor('Já existe um cadastro igual a este.', codigo: 'repetido');
    }
    if (e.code == '42501' || e.message.contains('row-level security')) {
      return const ErroServidor(
        'Você não tem permissão para fazer isso. Só o dono da empresa pode.',
        codigo: 'sem_permissao',
      );
    }
    if (e.code == '23514' && e.message.contains('plano')) return ErroServidor(e.message, codigo: 'limite');
    if (e.code == '23514' || e.code == '23503' || e.code == '22P02') {
      final m = e.message;
      // Mensagens dos gatilhos do banco já são em português.
      if (RegExp(
        r'[áéíóúãõç]|Informe|Escolha|valor|Lançamento|Caminhão|Categoria|campo',
        caseSensitive: false,
      ).hasMatch(m)) {
        return ErroServidor(m, codigo: e.code ?? '');
      }
      return const ErroServidor('Algum dado não foi aceito. Confira e tente de novo.', codigo: 'invalido');
    }
    if (_pareceSemInternet(texto)) return erroSemInternet;
    return const ErroServidor('Não deu certo agora. Tente de novo em instantes.');
  }
  if (e is AuthException) {
    final m = e.message.toLowerCase();
    if (e.code == 'invalid_credentials' || m.contains('invalid login')) {
      return const ErroServidor('E-mail ou senha incorretos.', codigo: 'login');
    }
    if (e.code == 'otp_expired' || m.contains('expired') || (m.contains('invalid') && m.contains('otp'))) {
      return const ErroServidor(
        'Este link foi cancelado por um pedido mais novo, venceu ou já foi usado.',
        codigo: 'link_vencido',
      );
    }
    if (m.contains('for security purposes') || m.contains('rate limit') || e.statusCode == '429') {
      return const ErroServidor('Espere um minuto antes de tentar de novo.', codigo: 'espera');
    }
    if (m.contains('password') && (m.contains('least') || m.contains('weak') || m.contains('should contain'))) {
      return const ErroServidor('A senha precisa ter pelo menos 8 caracteres, com letras e números.', codigo: 'senha_fraca');
    }
    if (m.contains('same') && m.contains('password')) {
      return const ErroServidor('Escolha uma senha diferente da anterior.', codigo: 'senha_igual');
    }
    if (m.contains('email not confirmed')) {
      return const ErroServidor('Confirme o seu e-mail pelo link antes de entrar.', codigo: 'email');
    }
    if (m.contains('signups not allowed') || m.contains('not allowed')) {
      return const ErroServidor('Não foi possível criar a conta com este e-mail.', codigo: 'cadastro');
    }
    if (m.contains('email') && m.contains('invalid')) {
      return const ErroServidor('Este e-mail não parece certo. Confira.', codigo: 'email');
    }
    if (_pareceSemInternet(texto)) return erroSemInternet;
    return const ErroServidor('Não deu certo. Confira os dados e tente de novo.', codigo: 'auth');
  }
  if (e is FunctionException) {
    final detalhes = e.details;
    if (detalhes is Map && detalhes['mensagem'] is String) {
      return ErroServidor(detalhes['mensagem'] as String, codigo: '${detalhes['codigo'] ?? ''}');
    }
  }
  if (_pareceSemInternet(texto)) return erroSemInternet;
  return const ErroServidor('Não deu certo agora. Tente de novo em instantes.');
}

Future<T> _tentar<T>(Future<T> Function() f) async {
  try {
    return await f().timeout(const Duration(seconds: 40));
  } catch (e) {
    throw traduzirErro(e);
  }
}

Map<String, Object?> _mapa(Object? v) => v is Map ? v.cast<String, Object?>() : <String, Object?>{};

class ServidorSupabase implements Servidor {
  ServidorSupabase(this.cliente);
  final SupabaseClient cliente;

  GoTrueClient get _auth => cliente.auth;

  @override
  bool get temSessao => _auth.currentSession != null;

  @override
  String? get emailDaSessao => _auth.currentUser?.email;

  @override
  String? get usuarioId => _auth.currentUser?.id;

  @override
  bool get precisaTrocarSenha => _auth.currentUser?.userMetadata?['trocar_senha'] == true;

  String _email(String e) => e.trim().toLowerCase();

  @override
  Future<void> entrar(String email, String senha) =>
      _tentar(() => _auth.signInWithPassword(email: _email(email), password: senha));

  @override
  Future<void> definirSenha(String senha) =>
      _tentar(() => _auth.updateUser(UserAttributes(password: senha, data: {'trocar_senha': false})));

  @override
  Future<Map<String, Object?>> completarCadastro(String nome) =>
      _tentar(() async => _mapa(await cliente.rpc('completar_cadastro', params: {'p_nome': nome.trim()})));

  @override
  Future<String> pedirLinkSenha(String email) => _tentar(() async {
    final r = await cliente.functions.invoke('pedir_link_senha', body: {'identificador': _email(email)});
    final d = _mapa(r.data);
    if (d['ok'] != true) throw ErroServidor('${d['mensagem'] ?? 'Não deu para pedir o link agora.'}');
    return '${d['mensagem']}';
  });

  @override
  Future<void> abrirLinkDoEmail(String tokenHash, {required bool senha}) => _tentar(
    () => _auth.verifyOTP(tokenHash: tokenHash, type: senha ? OtpType.recovery : OtpType.emailChange),
  );

  @override
  Future<Map<String, Object?>> situacao() => _tentar(() async => _mapa(await cliente.rpc('situacao_acesso')));

  /// Lê de 1000 em 1000 (limite do Supabase por consulta) até acabar.
  Future<List<Map<String, Object?>>> _tudo(String fonte) async {
    const passo = 1000;
    final linhas = <Map<String, Object?>>[];
    for (var de = 0; ; de += passo) {
      final parte = await cliente.from(fonte).select().order('id').range(de, de + passo - 1);
      linhas.addAll(parte.map((e) => Map<String, Object?>.from(e)));
      if (parte.length < passo) break;
    }
    return linhas;
  }

  @override
  Future<Map<String, List<Map<String, Object?>>>> carregar() => _tentar(() async {
    final listas = await Future.wait(Fontes.todas.map(_tudo));
    return {for (var i = 0; i < Fontes.todas.length; i++) Fontes.todas[i]: listas[i]};
  });

  @override
  Future<List<Map<String, Object?>>> pedidosEntrada() => _tentar(() async {
    final r = await cliente.rpc('pedidos_entrada_da_empresa');
    return [for (final p in (r as List? ?? const [])) _mapa(p)];
  });

  @override
  Future<void> decidirEntrada(String pedidoId, bool aprovar) =>
      _tentar(() => cliente.rpc('decidir_entrada', params: {'p_pedido_id': pedidoId, 'p_aprovar': aprovar}));

  @override
  Future<String> gerarNovoCodigo() => _tentar(() async => (await cliente.rpc('gerar_novo_codigo_entrada')).toString());

  @override
  Future<void> definirCaminhaoAtual(String motoristaId, String caminhaoId) => _tentar(
    () => cliente.rpc('definir_caminhao_atual', params: {'p_motorista_id': motoristaId, 'p_caminhao_id': caminhaoId}),
  );

  @override
  Future<Map<String, Object?>> redefinirAcesso(String motoristaId) => _tentar(() async {
    final r = await cliente.functions.invoke('redefinir_acesso', body: {'motorista_id': motoristaId});
    final d = _mapa(r.data);
    if (d['ok'] != true) throw ErroServidor('${d['mensagem'] ?? 'Não deu para redefinir agora.'}');
    return d;
  });

  @override
  Future<Map<String, Object?>> criarAcessoGestor(String email, String nome) => _tentar(() async {
    final r = await cliente.functions.invoke('criar_acesso_gestor', body: {'email': email.trim(), 'nome': nome.trim()});
    final d = _mapa(r.data);
    if (d['ok'] != true) throw ErroServidor('${d['mensagem'] ?? 'Não deu para criar o acesso agora.'}');
    return d;
  });

  @override
  Future<Map<String, Object?>> gerarConvite(String nome, String cpf, {String? modalidade}) => _tentar(
    () async => _mapa(
      await cliente.rpc(
        'gerar_convite_motorista',
        params: {'p_nome': nome.trim(), 'p_cpf': cpf, 'p_modalidade': ?modalidade},
      ),
    ),
  );

  List<Map<String, Object?>> _lista(Object? r) => [for (final e in (r as List? ?? const [])) _mapa(e)];

  @override
  Future<List<Map<String, Object?>>> modalidadesDaEmpresa() =>
      _tentar(() async => _lista(await cliente.rpc('modalidades_da_empresa')));

  @override
  Future<void> salvarModalidadeEmpresa(String codigo, bool ativa, {Map<String, Object?>? campos}) => _tentar(
    () => cliente.rpc(
      'salvar_modalidade_empresa',
      params: {'p_modalidade': codigo, 'p_ativa': ativa, 'p_campos': campos},
    ),
  );

  @override
  Future<void> definirModalidadeMotorista(String motoristaId, String codigo) => _tentar(
    () => cliente.rpc('definir_modalidade_motorista', params: {'p_motorista_id': motoristaId, 'p_modalidade': codigo}),
  );

  @override
  Future<Map<String, Object?>> fecharAcerto({
    required String id,
    required String motoristaId,
    required DateTime inicio,
    required DateTime fim,
    required int comissaoCentavos,
    required List<Map<String, Object?>> descontos,
    String? observacao,
  }) => _tentar(
    () async => _mapa(
      await cliente.rpc(
        'fechar_acerto',
        params: {
          'p_id': id,
          'p_motorista_id': motoristaId,
          'p_inicio': diaIso(inicio),
          'p_fim': diaIso(fim),
          'p_comissao_centavos': comissaoCentavos,
          'p_descontos': descontos,
          'p_observacao': observacao,
        },
      ),
    ),
  );

  @override
  Future<void> cancelarConvite(String conviteId) =>
      _tentar(() => cliente.rpc('cancelar_convite', params: {'p_convite_id': conviteId}));

  @override
  Future<void> excluirMotorista(String motoristaId) =>
      _tentar(() => cliente.rpc('excluir_motorista', params: {'p_motorista_id': motoristaId}));

  @override
  Future<void> excluirMinhaEmpresa(String confirmacao) =>
      _tentar(() => cliente.rpc('excluir_minha_empresa', params: {'p_confirmacao': confirmacao}));

  @override
  Future<Map<String, Object?>> aceitarTermos(String versao) =>
      _tentar(() async => _mapa(await cliente.rpc('aceitar_termos', params: {'p_versao': versao})));

  @override
  Future<void> registrarAcesso(String app) async {
    try {
      await cliente.rpc('registrar_acesso', params: {'p_app': app}).timeout(const Duration(seconds: 20));
    } catch (_) {
      // Sem internet: registra na próxima vez.
    }
  }

  @override
  Future<void> inserir(String tabela, Map<String, Object?> dados) => _tentar(() => cliente.from(tabela).insert(dados));

  @override
  Future<void> alterar(String tabela, String id, Map<String, Object?> campos) => _tentar(() async {
    // Sem linha devolvida = o RLS não deixou mudar (o banco não dá erro).
    final r = await cliente.from(tabela).update(campos).eq('id', id).select('id');
    if (r.isEmpty) {
      throw const ErroServidor(
        'Você não tem permissão para mudar isso. Só o dono da empresa pode.',
        codigo: 'sem_permissao',
      );
    }
  });

  @override
  Future<List<Map<String, Object?>>> plataformaEmpresas() => _tentar(() async {
    final r = await cliente.rpc('plataforma_empresas');
    return [for (final e in (r as List? ?? const [])) _mapa(e)];
  });

  @override
  Future<Map<String, Object?>> plataformaCriarEmpresa({
    required String nome,
    required String donoNome,
    required String donoEmail,
    required int? diasTeste,
    required int limiteCaminhoes,
  }) => _tentar(
    () async => _mapa(
      await cliente.rpc(
        'plataforma_criar_empresa',
        params: {
          'p_nome': nome,
          'p_dono_nome': donoNome,
          'p_dono_email': donoEmail,
          'p_dias_teste': diasTeste,
          'p_limite_caminhoes': limiteCaminhoes,
        },
      ),
    ),
  );

  @override
  Future<void> plataformaLiberar(String empresaId, {int? dias}) =>
      _tentar(() => cliente.rpc('plataforma_liberar', params: {'p_empresa': empresaId, 'p_dias': dias}));

  @override
  Future<void> plataformaBloquear(String empresaId, String motivo) =>
      _tentar(() => cliente.rpc('plataforma_bloquear', params: {'p_empresa': empresaId, 'p_motivo': motivo}));

  @override
  Future<Map<String, Object?>> plataformaNovaSenhaDono(String empresaId) => _tentar(
    () async => _mapa(await cliente.rpc('plataforma_nova_senha_dono', params: {'p_empresa': empresaId})),
  );

  @override
  Future<List<Map<String, Object?>>> plataformaModalidades() =>
      _tentar(() async => _lista(await cliente.rpc('plataforma_modalidades')));

  @override
  Future<void> plataformaSalvarModalidade({
    required String codigo,
    required String nome,
    required String tipo,
    bool ativa = true,
  }) => _tentar(
    () => cliente.rpc(
      'plataforma_salvar_modalidade',
      params: {'p_codigo': codigo, 'p_nome': nome, 'p_tipo': tipo, 'p_ativa': ativa},
    ),
  );

  @override
  Future<void> plataformaSalvarCampo(String modalidade, Map<String, Object?> campo) =>
      _tentar(() => cliente.rpc('plataforma_salvar_campo', params: {'p_modalidade': modalidade, 'p_campo': campo}));

  @override
  Future<void> sair({bool todosOsAparelhos = false}) async {
    try {
      await _auth.signOut(scope: todosOsAparelhos ? SignOutScope.global : SignOutScope.local);
    } catch (_) {
      // Sem internet: a sessão local some do mesmo jeito.
    }
  }
}
