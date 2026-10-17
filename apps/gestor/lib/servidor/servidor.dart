import 'dart:async';

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
  Future<void> pedirCodigoCadastro(String email);
  Future<void> confirmarCodigoCadastro(String email, String codigo);
  Future<void> definirSenha(String senha);
  Future<Map<String, Object?>> completarCadastro(String nome);
  Future<void> pedirCodigoSenha(String email);
  Future<void> confirmarCodigoSenha(String email, String codigo);
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

  /// Inclui uma linha (caminhões, categorias, acessos e ajustes).
  Future<void> inserir(String tabela, Map<String, Object?> dados);

  /// Muda colunas de uma linha (só as que o banco libera para cada perfil).
  Future<void> alterar(String tabela, String id, Map<String, Object?> campos);
  Future<void> sair();
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
    if (m.contains('expired') || (m.contains('invalid') && m.contains('otp')) || m.contains('token has expired')) {
      return const ErroServidor('Código errado ou vencido. Confira ou peça outro.', codigo: 'codigo');
    }
    if (m.contains('for security purposes') || m.contains('rate limit') || e.statusCode == '429') {
      return const ErroServidor('Espere um minuto antes de tentar de novo.', codigo: 'espera');
    }
    if (m.contains('password') && m.contains('least')) {
      return const ErroServidor('A senha precisa ter pelo menos 6 letras ou números.', codigo: 'senha_curta');
    }
    if (m.contains('same') && m.contains('password')) {
      return const ErroServidor('Escolha uma senha diferente da anterior.', codigo: 'senha_igual');
    }
    if (m.contains('email not confirmed')) {
      return const ErroServidor('Confirme o seu e-mail com o código antes de entrar.', codigo: 'email');
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
  Future<void> pedirCodigoCadastro(String email) =>
      _tentar(() => _auth.signInWithOtp(email: _email(email), shouldCreateUser: true));

  @override
  Future<void> confirmarCodigoCadastro(String email, String codigo) =>
      _tentar(() => _auth.verifyOTP(email: _email(email), token: codigo.trim(), type: OtpType.email));

  @override
  Future<void> definirSenha(String senha) =>
      _tentar(() => _auth.updateUser(UserAttributes(password: senha, data: {'trocar_senha': false})));

  @override
  Future<Map<String, Object?>> completarCadastro(String nome) =>
      _tentar(() async => _mapa(await cliente.rpc('completar_cadastro', params: {'p_nome': nome.trim()})));

  @override
  Future<void> pedirCodigoSenha(String email) => _tentar(() => _auth.resetPasswordForEmail(_email(email)));

  @override
  Future<void> confirmarCodigoSenha(String email, String codigo) =>
      _tentar(() => _auth.verifyOTP(email: _email(email), token: codigo.trim(), type: OtpType.recovery));

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
  Future<void> sair() async {
    try {
      await _auth.signOut();
    } catch (_) {
      // Sem internet: a sessão local some do mesmo jeito.
    }
  }
}
