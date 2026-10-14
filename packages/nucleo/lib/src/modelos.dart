/// Modelos simples de dados da plataforma de frota.
///
/// Esta etapa não contém cálculos nem regras de negócio.
class Empresa {
  const Empresa({
    required this.id,
    required this.empresaId,
    required this.nome,
    required this.plano,
    required this.limiteCaminhoes,
    required this.status,
    this.documento,
    this.codigoEntrada,
  });

  final String id;
  final String empresaId;
  final String nome;
  final String? documento;
  final String? codigoEntrada;
  final String plano;
  final int limiteCaminhoes;
  final String status;
}

class Perfil {
  const Perfil({
    required this.id,
    required this.papel,
    required this.nome,
    required this.cpf,
    required this.email,
    required this.ativo,
    this.empresaId,
  });

  final String id;
  final String? empresaId;
  final String papel;
  final String nome;
  final String cpf;
  final String email;
  final bool ativo;
}

class Motorista {
  const Motorista({
    required this.id,
    required this.empresaId,
    required this.perfilId,
    required this.nome,
    required this.cpf,
    required this.email,
    required this.ativo,
    this.telefone,
  });

  final String id;
  final String empresaId;
  final String perfilId;
  final String nome;
  final String cpf;
  final String email;
  final String? telefone;
  final bool ativo;
}

class Caminhao {
  const Caminhao({
    required this.id,
    required this.empresaId,
    required this.placa,
    required this.modelo,
    required this.ativo,
    required this.confirmado,
    this.numeroFrota,
    this.ano,
  });

  final String id;
  final String empresaId;
  final String placa;
  final String? numeroFrota;
  final String modelo;
  final int? ano;
  final bool ativo;
  final bool confirmado;
}

class Frete {
  const Frete({
    required this.id,
    required this.empresaId,
    required this.motoristaId,
    required this.caminhaoId,
    required this.origem,
    required this.destino,
    required this.embarcador,
    required this.dataCarga,
    required this.pesoCargaKg,
    required this.valorToneladaCentavos,
    required this.adiantamentoCentavos,
    required this.saldoCentavos,
    required this.percentualComissao,
    required this.comissaoSobreBruto,
    required this.pedagioCentavos,
    required this.pesoDescargaKg,
    required this.descontoQuebraCentavos,
  });

  final String id;
  final String empresaId;
  final String motoristaId;
  final String caminhaoId;
  final String origem;
  final String destino;
  final String embarcador;
  final DateTime dataCarga;
  final double pesoCargaKg;
  final int valorToneladaCentavos;
  final int adiantamentoCentavos;
  final int saldoCentavos;
  final double percentualComissao;
  final bool comissaoSobreBruto;
  final int pedagioCentavos;
  final double pesoDescargaKg;
  final int descontoQuebraCentavos;
}

class Abastecimento {
  const Abastecimento({
    required this.id,
    required this.empresaId,
    required this.motoristaId,
    required this.caminhaoId,
    required this.data,
    required this.cidade,
    required this.posto,
    required this.litros,
    required this.valorCentavos,
    required this.kmOdometro,
    required this.tanqueCheio,
    required this.pontoDePartida,
    this.freteId,
  });

  final String id;
  final String empresaId;
  final String motoristaId;
  final String caminhaoId;
  final String? freteId;
  final DateTime data;
  final String cidade;
  final String posto;
  final double litros;
  final int valorCentavos;
  final double kmOdometro;
  final bool tanqueCheio;
  final bool pontoDePartida;
}

class CategoriaGasto {
  const CategoriaGasto({
    required this.id,
    required this.empresaId,
    required this.nome,
    required this.ativa,
  });

  final String id;
  final String empresaId;
  final String nome;
  final bool ativa;
}

class GastoViagem {
  const GastoViagem({
    required this.id,
    required this.empresaId,
    required this.motoristaId,
    required this.caminhaoId,
    required this.data,
    required this.categoriaId,
    required this.valorCentavos,
    this.freteId,
    this.observacao,
  });

  final String id;
  final String empresaId;
  final String motoristaId;
  final String caminhaoId;
  final String? freteId;
  final DateTime data;
  final String categoriaId;
  final int valorCentavos;
  final String? observacao;
}

class Vale {
  const Vale({
    required this.id,
    required this.empresaId,
    required this.motoristaId,
    required this.data,
    required this.valorCentavos,
    this.observacao,
  });

  final String id;
  final String empresaId;
  final String motoristaId;
  final DateTime data;
  final int valorCentavos;
  final String? observacao;
}

class AcessoAutorizado {
  const AcessoAutorizado({
    required this.id,
    required this.empresaId,
    required this.email,
    required this.papel,
    required this.ativo,
  });

  final String id;
  final String empresaId;
  final String email;
  final String papel;
  final bool ativo;
}

class Dispositivo {
  const Dispositivo({
    required this.id,
    required this.empresaId,
    required this.perfilId,
    required this.apelido,
    this.ultimoSyncEm,
    this.revogadoEm,
  });

  final String id;
  final String empresaId;
  final String perfilId;
  final String apelido;
  final DateTime? ultimoSyncEm;
  final DateTime? revogadoEm;
}

class AjusteKm {
  const AjusteKm({
    required this.id,
    required this.empresaId,
    required this.caminhaoId,
    required this.motoristaId,
    required this.quando,
    required this.kmAnterior,
    required this.kmNovo,
    required this.motivo,
  });

  final String id;
  final String empresaId;
  final String caminhaoId;
  final String motoristaId;
  final DateTime quando;
  final double kmAnterior;
  final double kmNovo;
  final String motivo;
}

class AjusteGestor {
  const AjusteGestor({
    required this.id,
    required this.empresaId,
    required this.tabelaAlvo,
    required this.registroId,
    required this.campo,
    required this.motivo,
    required this.autorId,
    this.valorAntigo,
    this.valorNovo,
  });

  final String id;
  final String empresaId;
  final String tabelaAlvo;
  final String registroId;
  final String campo;
  final Object? valorAntigo;
  final Object? valorNovo;
  final String motivo;
  final String autorId;
}

class Auditoria {
  const Auditoria({
    required this.id,
    required this.empresaId,
    required this.acao,
    required this.tabela,
    required this.registroId,
    this.autorId,
    this.antes,
    this.depois,
  });

  final String id;
  final String empresaId;
  final String? autorId;
  final String acao;
  final String tabela;
  final String registroId;
  final Map<String, Object?>? antes;
  final Map<String, Object?>? depois;
}

class PedidoEntrada {
  const PedidoEntrada({
    required this.id,
    required this.empresaId,
    required this.perfilId,
    required this.status,
    required this.pedidoEm,
    this.decididoPor,
    this.decididoEm,
  });

  final String id;
  final String empresaId;
  final String perfilId;
  final String status;
  final DateTime pedidoEm;
  final String? decididoPor;
  final DateTime? decididoEm;
}

class UsoCaminhao {
  const UsoCaminhao({
    required this.id,
    required this.empresaId,
    required this.motoristaId,
    required this.caminhaoId,
    required this.inicioEm,
    required this.registradoPor,
    this.fimEm,
  });

  final String id;
  final String empresaId;
  final String motoristaId;
  final String caminhaoId;
  final DateTime inicioEm;
  final DateTime? fimEm;
  final String registradoPor;
}
