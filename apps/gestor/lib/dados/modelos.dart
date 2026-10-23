import 'package:nucleo/nucleo.dart';

/// Dados da empresa (tabela empresas) que o painel mostra e o dono edita.
class Empresa {
  const Empresa({
    required this.id,
    required this.nome,
    this.documento,
    this.codigoEntrada,
    this.status = 'teste',
    this.plano = 'piloto',
    this.limiteCaminhoes = 5,
    this.configuracao = const ConfiguracaoEmpresa(),
    this.acessoAte,
    this.paradasAtivas = false,
    this.limiteSemDescansoMinutos,
    this.excluirEm,
  });

  final String id;
  final String nome;
  final String? documento;
  final String? codigoEntrada;
  final String status;
  final String plano;
  final int limiteCaminhoes;
  final ConfiguracaoEmpresa configuracao;

  /// Fim do período de teste (nulo = sem prazo).
  final DateTime? acessoAte;

  /// Quando os dados serão apagados (fim do acesso; vem da situação da conta).
  final DateTime? excluirEm;

  /// Registro de paradas ligado (o dono liga em Configurações).
  final bool paradasAtivas;

  /// Tempo máximo sem descanso que a empresa definiu, em minutos.
  final int? limiteSemDescansoMinutos;

  bool get suspensa => status == 'suspensa';
  bool get emTeste => status == 'teste';

  factory Empresa.deMapa(Map<String, Object?> m) => Empresa(
    id: lerTexto(m['id']),
    nome: lerTexto(m['nome']),
    documento: lerTextoOuNulo(m['documento']),
    codigoEntrada: lerTextoOuNulo(m['codigo_entrada']),
    status: lerTexto(m['status'], 'teste'),
    plano: lerTexto(m['plano'], 'piloto'),
    limiteCaminhoes: lerInt(m['limite_caminhoes'], 5),
    configuracao: ConfiguracaoEmpresa.deMapa(m),
    acessoAte: lerDataOuNula(m['acesso_ate']),
    paradasAtivas: lerBool(m['paradas_ativas']),
    excluirEm: lerDataOuNula(m['excluir_em']),
    limiteSemDescansoMinutos: m['limite_sem_descanso_minutos'] == null ? null : lerInt(m['limite_sem_descanso_minutos']),
  );
}

/// Pessoa com conta (dono, gestor ou motorista).
class Perfil {
  const Perfil({
    required this.id,
    required this.nome,
    this.email = '',
    this.papel = 'gestor',
    this.ativo = true,
    this.exclusaoPedidaEm,
  });

  final String id;
  final String nome;
  final String email;
  final String papel;
  final bool ativo;

  /// O motorista pediu para excluir a conta (os dados somem 15 dias depois).
  final DateTime? exclusaoPedidaEm;

  bool get dono => papel == 'dono';

  factory Perfil.deMapa(Map<String, Object?> m) => Perfil(
    id: lerTexto(m['id']),
    nome: lerTexto(m['nome']),
    email: lerTexto(m['email']),
    papel: lerTexto(m['papel'], 'gestor'),
    ativo: lerBool(m['ativo'], true) && m['apagado_em'] == null,
    exclusaoPedidaEm: lerDataOuNula(m['exclusao_pedida_em']),
  );
}

/// Código individual gerado pelo gestor para um motorista entrar na empresa.
class Convite {
  const Convite({
    required this.id,
    required this.codigo,
    required this.nome,
    required this.cpf,
    required this.expiraEm,
    this.usadoEm,
    this.canceladoEm,
    this.modalidade,
  });

  final String id;
  final String codigo;

  /// Modalidade com que o motorista entra (nula = a empresa tem uma só, ou ele escolhe).
  final String? modalidade;
  final String nome;
  final String cpf;
  final DateTime expiraEm;
  final DateTime? usadoEm;
  final DateTime? canceladoEm;

  /// Ainda pode ser usado (não usado, não cancelado e dentro do prazo).
  bool valeEm(DateTime agora) => usadoEm == null && canceladoEm == null && expiraEm.isAfter(agora);

  factory Convite.deMapa(Map<String, Object?> m) => Convite(
    id: lerTexto(m['id']),
    codigo: lerTexto(m['codigo']),
    nome: lerTexto(m['nome']),
    cpf: lerTexto(m['cpf']),
    expiraEm: lerDataOuNula(m['expira_em']) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    usadoEm: lerDataOuNula(m['usado_em']),
    canceladoEm: lerDataOuNula(m['cancelado_em']),
    modalidade: lerTextoOuNulo(m['modalidade']),
  );
}

class Motorista {
  const Motorista({
    required this.id,
    required this.perfilId,
    required this.nome,
    this.cpf = '',
    this.email = '',
    this.telefone,
    this.ativo = true,
    this.modalidade,
  });

  final String id;
  final String perfilId;

  /// Graneleiro, Baú... (nula = ainda não escolheu; a empresa tem mais de uma).
  final String? modalidade;
  final String nome;
  final String cpf;
  final String email;
  final String? telefone;
  final bool ativo;

  String get primeiroNome => nome.trim().split(RegExp(r'\s+')).first;

  factory Motorista.deMapa(Map<String, Object?> m) => Motorista(
    id: lerTexto(m['id']),
    perfilId: lerTexto(m['perfil_id']),
    nome: lerTexto(m['nome']),
    cpf: lerTexto(m['cpf']),
    email: lerTexto(m['email']),
    telefone: lerTextoOuNulo(m['telefone']),
    ativo: lerBool(m['ativo'], true),
    modalidade: lerTextoOuNulo(m['modalidade']),
  );
}

/// Motorista que digitou o código da empresa e espera aprovação.
class PedidoEntrada {
  const PedidoEntrada({
    required this.id,
    required this.status,
    required this.pedidoEm,
    this.decididoEm,
    required this.perfilId,
    required this.nome,
    this.cpf = '',
    this.email = '',
  });

  final String id;
  final String status;
  final DateTime pedidoEm;
  final DateTime? decididoEm;
  final String perfilId;
  final String nome;
  final String cpf;
  final String email;

  bool get pendente => status == 'pendente';

  factory PedidoEntrada.deMapa(Map<String, Object?> m) => PedidoEntrada(
    id: lerTexto(m['id']),
    status: lerTexto(m['status']),
    pedidoEm: lerData(m['pedido_em']),
    decididoEm: lerDataOuNula(m['decidido_em']),
    perfilId: lerTexto(m['perfil_id']),
    nome: lerTexto(m['nome']),
    cpf: lerTexto(m['cpf']),
    email: lerTexto(m['email']),
  );
}

/// Celular de motorista que já enviou dados.
class Dispositivo {
  const Dispositivo({
    required this.id,
    required this.perfilId,
    required this.apelido,
    this.ultimoEnvio,
    this.revogadoEm,
  });

  final String id;
  final String perfilId;
  final String apelido;
  final DateTime? ultimoEnvio;
  final DateTime? revogadoEm;

  bool get revogado => revogadoEm != null;

  factory Dispositivo.deMapa(Map<String, Object?> m) => Dispositivo(
    id: lerTexto(m['id']),
    perfilId: lerTexto(m['perfil_id']),
    apelido: lerTexto(m['apelido'], 'Celular'),
    ultimoEnvio: lerDataOuNula(m['ultimo_sync_em']),
    revogadoEm: lerDataOuNula(m['revogado_em']),
  );
}

/// E-mail liberado pelo dono para entrar como dono ou gestor.
class AcessoAutorizado {
  const AcessoAutorizado({required this.id, required this.email, required this.papel, this.ativo = true});

  final String id;
  final String email;
  final String papel;
  final bool ativo;

  factory AcessoAutorizado.deMapa(Map<String, Object?> m) => AcessoAutorizado(
    id: lerTexto(m['id']),
    email: lerTexto(m['email']),
    papel: lerTexto(m['papel'], 'gestor'),
    ativo: lerBool(m['ativo'], true),
  );
}

/// Tipo de valor de cada campo que o gestor pode corrigir (igual à função
/// campo_ajustavel_tipo do banco).
enum TipoAjuste { texto, data, centavos, numero, percentual, logico, caminhao, categoria }

const camposAjustaveis = <String, Map<String, TipoAjuste>>{
  'fretes': {
    'data_carga': TipoAjuste.data,
    'origem': TipoAjuste.texto,
    'destino': TipoAjuste.texto,
    'embarcador': TipoAjuste.texto,
    'caminhao_id': TipoAjuste.caminhao,
    'peso_carga_kg': TipoAjuste.numero,
    'valor_tonelada_centavos': TipoAjuste.centavos,
    'adiantamento_centavos': TipoAjuste.centavos,
    'saldo_centavos': TipoAjuste.centavos,
    'pedagio_centavos': TipoAjuste.centavos,
    'peso_descarga_kg': TipoAjuste.numero,
    'desconto_quebra_centavos': TipoAjuste.centavos,
    'percentual_comissao': TipoAjuste.percentual,
    'comissao_sobre_bruto': TipoAjuste.logico,
  },
  'abastecimentos': {
    'data': TipoAjuste.data,
    'caminhao_id': TipoAjuste.caminhao,
    'cidade': TipoAjuste.texto,
    'posto': TipoAjuste.texto,
    'km_odometro': TipoAjuste.numero,
    'litros': TipoAjuste.numero,
    'valor_centavos': TipoAjuste.centavos,
    'tanque_cheio': TipoAjuste.logico,
  },
  'gastos_viagem': {
    'data': TipoAjuste.data,
    'caminhao_id': TipoAjuste.caminhao,
    'categoria_id': TipoAjuste.categoria,
    'valor_centavos': TipoAjuste.centavos,
    'observacao': TipoAjuste.texto,
  },
  'vales': {'data': TipoAjuste.data, 'valor_centavos': TipoAjuste.centavos, 'observacao': TipoAjuste.texto},
};

/// Nome de cada tipo de lançamento, para títulos.
const nomesDasTabelas = <String, String>{
  'viagens': 'Viagem',
  'fretes': 'Frete',
  'abastecimentos': 'Abastecida',
  'gastos_viagem': 'Gasto',
  'vales': 'Vale',
};
