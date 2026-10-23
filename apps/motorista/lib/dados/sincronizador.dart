import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../acesso/acesso.dart';
import '../servidor/servidor.dart';
import 'armazenamento.dart';
import 'dados.dart';

/// Como está o envio para a nuvem (aparece em linguagem simples na tela).
class EstadoEnvio {
  const EstadoEnvio({
    this.ocupado = false,
    this.ultimaVez,
    this.erro,
    this.precisaEntrar = false,
    this.desligado = false,
  });

  final bool ocupado;
  final DateTime? ultimaVez;

  /// Última falha (sem internet, sessão vencida...).
  final String? erro;

  /// A sessão venceu: só pede o login quando tiver sinal.
  final bool precisaEntrar;

  /// A empresa desativou este motorista ou este celular.
  final bool desligado;

  EstadoEnvio copyWith({
    bool? ocupado,
    DateTime? ultimaVez,
    String? erro,
    bool limparErro = false,
    bool? precisaEntrar,
    bool? desligado,
  }) => EstadoEnvio(
    ocupado: ocupado ?? this.ocupado,
    ultimaVez: ultimaVez ?? this.ultimaVez,
    erro: limparErro ? null : (erro ?? this.erro),
    precisaEntrar: precisaEntrar ?? this.precisaEntrar,
    desligado: desligado ?? this.desligado,
  );
}

/// Leva a fila do celular para a nuvem e traz o que mudou (cadastros,
/// ajustes do gestor e o histórico, se o celular é novo).
class Sincronizador extends Notifier<EstadoEnvio> {
  static const tamanhoDoLote = 200;
  Future<void>? _rodando;
  bool _acessoRegistrado = false;

  Armazenamento get _a => ref.read(armazenamentoProvider);
  Servidor get _s => ref.read(servidorProvider);

  @override
  EstadoEnvio build() {
    _lerUltimaVez();
    return const EstadoEnvio();
  }

  Future<void> _lerUltimaVez() async {
    final t = await _a.lerEstado('ultimo_envio');
    if (t != null) state = state.copyWith(ultimaVez: DateTime.tryParse(t));
  }

  /// Envia e recebe. Chamadas ao mesmo tempo esperam a que está rodando.
  Future<void> sincronizar() => _rodando ??= _executar().whenComplete(() => _rodando = null);

  Future<void> _executar() async {
    if (!_s.temSessao) {
      state = state.copyWith(precisaEntrar: true);
      return;
    }
    state = state.copyWith(ocupado: true, limparErro: true);
    try {
      await enviar();
      await baixar();
      final agora = ref.read(relogioProvider)();
      await _a.gravarEstado('ultimo_envio', agora.toIso8601String());
      state = state.copyWith(ocupado: false, ultimaVez: agora, precisaEntrar: false, desligado: false);
      if (!_acessoRegistrado) {
        _acessoRegistrado = true;
        unawaited(_s.registrarAcesso());
      }
    } on ErroServidor catch (e) {
      state = state.copyWith(
        ocupado: false,
        erro: e.mensagem,
        precisaEntrar: e.codigo == 'sessao',
        desligado: e.codigo == 'sem_vinculo' || e.codigo == 'dispositivo_revogado',
      );
      // Empresa bloqueada, cadastro excluído ou termos novos: a tela muda.
      if (const {'sem_vinculo', 'empresa_bloqueada', 'termos'}.contains(e.codigo)) {
        unawaited(ref.read(acessoProvider.notifier).conferirEmSilencio());
      }
    } catch (e) {
      state = state.copyWith(ocupado: false, erro: traduzirErro(e).mensagem);
    } finally {
      await ref.read(dadosProvider.notifier).recarregar();
    }
  }

  Future<String> _dispositivo() => idDoAparelho(_a);

  /// Manda a fila em lotes até esvaziar. Só tira da fila o que o servidor
  /// confirmou; se a internet cair no meio, o resto vai na próxima.
  Future<void> enviar() async {
    final dispositivo = await _dispositivo();
    for (var voltas = 0; voltas < 50; voltas++) {
      final itens = await _a.fila(situacao: 'pendente', limite: tamanhoDoLote);
      if (itens.isEmpty) return;
      final resposta = await _s.sincronizarLote({
        'dispositivo_id': dispositivo,
        'apelido': 'Celular do motorista',
        'itens': [
          for (final i in itens) {'tabela': i.tabela, 'dados': i.dados},
        ],
      });
      final porChave = {for (final i in itens) i.chave: i};
      var andou = false;

      for (final a in (resposta['aceitos'] as List? ?? const [])) {
        final m = (a as Map).cast<String, Object?>();
        final item = porChave['${m['tabela']}:${m['id']}'];
        if (item == null) continue;
        await _a.confirmarEnvio(item.seq, item.versao);
        andou = true;
        final novo = m['substituido_por'] as String?;
        if (m['tabela'] == Tabelas.caminhoes && novo != null && novo != item.registroId) {
          // O gestor já tinha esta placa: passa a usar o caminhão dele.
          final atual = (m['atual'] as Map?)?.cast<String, Object?>();
          if (atual != null) await _a.gravarRegistros(Tabelas.caminhoes, [_caminhao(atual)]);
          await _a.trocarCaminhao(item.registroId, novo);
        }
      }

      if (resposta['suspensa'] == true) {
        // Fica tudo na fila, guardado, até a empresa voltar.
        throw const ErroServidor(
          'A empresa está suspensa. Seus lançamentos estão guardados no celular.',
          codigo: 'suspensa',
        );
      }

      for (final r in (resposta['rejeitados'] as List? ?? const [])) {
        final m = (r as Map).cast<String, Object?>();
        final item = porChave['${m['tabela']}:${m['id']}'];
        if (item == null) continue;
        andou = true;
        final atual = (m['atual'] as Map?)?.cast<String, Object?>();
        final motivo = m['motivo'] as String? ?? '';
        if ((motivo == 'ajustado' || motivo == 'apagado') && atual != null) {
          // Vale o que está no servidor; o celular volta ao certo.
          await _a.gravarRegistros(item.tabela, [atual]);
          await _a.marcarRecusado(item.seq, item.versao, '${m['mensagem'] ?? 'Não foi aceito.'}');
        } else if (motivo == 'apagado') {
          await _a.confirmarEnvio(item.seq, item.versao);
        } else {
          await _a.marcarRecusado(item.seq, item.versao, '${m['mensagem'] ?? 'Não foi aceito.'}');
        }
      }
      if (!andou) return;
    }
  }

  Map<String, Object?> _caminhao(Map<String, Object?> c) => {
    'id': c['id'],
    'placa': c['placa'],
    'numero_frota': c['numero_frota'],
    'modelo': c['modelo'] ?? '',
    'ativo': c['ativo'] ?? true,
    'confirmado': c['confirmado'] ?? true,
  };

  /// Traz o que mudou desde a última vez (ou tudo, na primeira).
  Future<void> baixar({bool tudo = false}) async {
    final desdeTexto = tudo ? null : await _a.lerEstado('baixado_ate');
    final desde = desdeTexto == null ? null : DateTime.tryParse(desdeTexto);
    final r = await _s.baixarAlteracoes(desde);

    final situacao = (r['situacao'] as Map?)?.cast<String, Object?>();
    if (situacao != null) await _a.gravarEstado('situacao', situacaoParaGuardar(situacao));
    if ((situacao?['empresa'] as Map?)?['bloqueada'] == true) {
      throw const ErroServidor('O acesso da empresa à plataforma foi encerrado.', codigo: 'empresa_bloqueada');
    }
    if ((situacao?['termos'] as Map?)?['aceito'] == false) {
      throw const ErroServidor('Aceite os Termos de Uso para continuar.', codigo: 'termos');
    }
    final motorista = situacao?['motorista'] as Map?;
    if (motorista == null || motorista['ativo'] == false) {
      throw const ErroServidor('Sua conta foi desligada da empresa. Fale com o seu patrão.', codigo: 'sem_vinculo');
    }

    final fila = await _a.fila();
    final naFila = {for (final i in fila) i.chave};
    for (final t in [
      Tabelas.caminhoes,
      Tabelas.categorias,
      Tabelas.fretes,
      Tabelas.viagens,
      Tabelas.abastecimentos,
      Tabelas.gastos,
      Tabelas.vales,
      Tabelas.ajustesKm,
      Tabelas.usos,
      Tabelas.acertos,
    ]) {
      final chaveResposta = t == Tabelas.categorias ? 'categorias' : t;
      final lista = [for (final e in (r[chaveResposta] as List? ?? const [])) (e as Map).cast<String, Object?>()];
      // O que o motorista mudou e ainda não enviou vale mais que a cópia da nuvem.
      final gravar = [
        for (final m in lista)
          if (!naFila.contains('$t:${m['id']}')) m,
      ];
      if (gravar.isNotEmpty) await _a.gravarRegistros(t, gravar);
    }
    final ajustes = [for (final e in (r['ajustes'] as List? ?? const [])) (e as Map).cast<String, Object?>()];
    if (ajustes.isNotEmpty) await _a.gravarRegistros(Tabelas.ajustes, ajustes);

    final ate = r['servidor_em'] as String?;
    if (ate != null) await _a.gravarEstado('baixado_ate', ate);
  }
}

final sincronizadorProvider = NotifierProvider<Sincronizador, EstadoEnvio>(Sincronizador.new);
