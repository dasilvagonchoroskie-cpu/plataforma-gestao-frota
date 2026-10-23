import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/comuns.dart';
import '../../dados/dados.dart';
import 'form_parada.dart';

/// Aba Paradas (só quando a empresa liga): "Registrar parada" grava o motivo
/// e a hora do toque; "Retomar viagem" fecha a parada. Funciona sem internet.
class TelaParadas extends ConsumerWidget {
  const TelaParadas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dados = assistirDados(ref);
    final agora = ref.read(relogioProvider)();
    final aberta = dados.paradaEmAndamento;
    final motivos = dados.info.paradas.motivos;
    final grupos = agruparPorDia<Parada>(dados.paradas, (p) => p.inicioEm);

    return Scaffold(
      appBar: AppBar(title: const Text('Paradas')),
      // Parado: o botão de retomar já está no cartão de cima.
      floatingActionButton: aberta != null
          ? null
          : FloatingActionButton.extended(
              heroTag: 'parada',
              onPressed: () => registrarParada(context, ref),
              icon: const Icon(Icons.pause),
              label: const Text('Registrar parada'),
            ),
      body: ListView(
        children: [
          const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 4), child: CartaoSituacaoParada()),
          if (dados.paradas.isEmpty)
            const EstadoVazio(
              icone: Icons.pause_circle_outline,
              titulo: 'Nenhuma parada registrada',
              texto:
                  'Parou o caminhão? Toque em "Registrar parada" e escolha o motivo. Na hora de sair, toque em '
                  '"Retomar viagem". Funciona sem internet.',
            )
          else ...[
            for (final g in grupos) ...[
              CabecalhoMes(titulo: tituloDoDia(g.dia, agora), resumo: plural(g.itens.length, 'parada', 'paradas')),
              for (var i = 0; i < g.itens.length; i++) ...[
                if (i > 0) const Divider(indent: 68, endIndent: 20),
                LinhaParada(
                  parada: g.itens[i],
                  motivos: motivos,
                  agora: agora,
                  pendente: dados.estaPendente(Tabelas.paradas, g.itens[i].id),
                  aoTocar: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => FormParada(parada: g.itens[i])),
                  ),
                ),
              ],
            ],
            const Padding(padding: EdgeInsets.fromLTRB(20, 16, 20, 0), child: Nota(avisoParadas)),
            espacoFinalLista,
          ],
        ],
      ),
    );
  }
}

/// "Registrar parada": escolhe o motivo (e, se esqueceu, a hora em que parou).
Future<void> registrarParada(BuildContext context, WidgetRef ref) async {
  final dados = ref.read(dadosProvider).value ?? const EstadoDados();
  final escolha = await showModalBottomSheet<(String, bool)>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _EscolherMotivo(motivos: dados.info.paradas.motivosAtivos),
  );
  if (escolha == null || !context.mounted) return;
  final (motivo, esqueceu) = escolha;

  String? descricao;
  if (motivo == 'outro') {
    descricao = await _perguntarDescricao(context);
    if (descricao == null || !context.mounted) return;
  }
  DateTime? inicio;
  if (esqueceu) {
    inicio = await escolherDataHora(context, rotulo: 'Que horas você parou?');
    if (inicio == null || !context.mounted) return;
    final agora = ref.read(relogioProvider)();
    if (inicio.isAfter(agora)) {
      mostrarMensagem(context, 'Esse horário ainda não chegou. Confira a hora.');
      return;
    }
  }
  final p = await ref.read(dadosProvider.notifier).registrarParada(motivo, descricao: descricao, inicio: inicio);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  mostrarMensagem(
    context,
    'Parada registrada: ${nomeDoMotivo(p.motivo, dados.info.paradas.motivos)}, às ${horaTexto(p.inicioEm)}.',
  );
}

/// "Retomar viagem": fecha a parada aberta na hora do toque.
Future<void> retomarViagem(BuildContext context, WidgetRef ref, {bool esqueceu = false}) async {
  final dados = ref.read(dadosProvider).value ?? const EstadoDados();
  final aberta = dados.paradaEmAndamento;
  if (aberta == null) return;
  DateTime? fim;
  if (esqueceu) {
    fim = await escolherDataHora(context, rotulo: 'Que horas você saiu?', inicial: aberta.inicioEm);
    if (fim == null || !context.mounted) return;
    final agora = ref.read(relogioProvider)();
    // Mesmo minuto da parada vale (o relógio de escolher hora não tem segundos).
    if (fim.isBefore(ateOMinuto(aberta.inicioEm))) {
      mostrarMensagem(context, 'A saída não pode ser antes da parada (${dataHoraTexto(aberta.inicioEm)}).');
      return;
    }
    if (fim.isAfter(agora)) {
      mostrarMensagem(context, 'Esse horário ainda não chegou. Confira a hora.');
      return;
    }
  }
  await ref.read(dadosProvider.notifier).retomarViagem(fim: fim);
  if (!context.mounted) return;
  final fechada = (ref.read(dadosProvider).value ?? const EstadoDados()).paradas.firstWhere(
    (p) => p.id == aberta.id,
    orElse: () => aberta,
  );
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  mostrarMensagem(
    context,
    'Boa viagem! A parada durou ${duracaoTexto(fechada.duracao(ref.read(relogioProvider)()))}.',
  );
}

Future<String?> _perguntarDescricao(BuildContext context) {
  final controle = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Qual foi o motivo?'),
      content: TextField(
        controller: controle,
        autofocus: true,
        maxLength: 120,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Ex.: esperando a balança'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, controle.text.trim()), child: const Text('Registrar')),
      ],
    ),
  );
}

class _EscolherMotivo extends StatefulWidget {
  const _EscolherMotivo({required this.motivos});
  final List<MotivoParada> motivos;

  @override
  State<_EscolherMotivo> createState() => _EscolherMotivoState();
}

class _EscolherMotivoState extends State<_EscolherMotivo> {
  var _esqueceu = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text('Por que você parou?', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600)),
            ),
            SwitchListTile(
              value: _esqueceu,
              onChanged: (v) => setState(() => _esqueceu = v),
              title: const Text('Parei antes e esqueci de registrar'),
              subtitle: const Text('Você informa a hora em que parou'),
            ),
            const Divider(height: 1),
            for (final m in widget.motivos)
              ListTile(
                leading: Icon(iconeDoMotivo(m.codigo), size: 28),
                title: Text(m.nome, style: const TextStyle(fontSize: 18.5, fontWeight: FontWeight.w600)),
                subtitle: m.contaComoDescanso ? const Text('Conta como descanso') : null,
                minVerticalPadding: 10,
                onTap: () => Navigator.pop(context, (m.codigo, _esqueceu)),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// O que está acontecendo agora: parado (com "Retomar viagem") ou rodando,
/// com o tempo desde o último descanso. Aparece também no Resumo.
class CartaoSituacaoParada extends ConsumerStatefulWidget {
  const CartaoSituacaoParada({super.key, this.soQuandoParado = false});

  /// No Resumo, só aparece quando há uma parada aberta.
  final bool soQuandoParado;

  @override
  ConsumerState<CartaoSituacaoParada> createState() => _CartaoSituacaoParadaState();
}

class _CartaoSituacaoParadaState extends ConsumerState<CartaoSituacaoParada> {
  Timer? _relogio;

  @override
  void initState() {
    super.initState();
    // O "há quanto tempo" anda sozinho com a tela aberta.
    _relogio = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _relogio?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dados = assistirDados(ref);
    final cores = context.cores;
    final esquema = Theme.of(context).colorScheme;
    final agora = ref.read(relogioProvider)();
    final aberta = dados.paradaEmAndamento;
    final config = dados.info.paradas;
    if (aberta == null && widget.soQuandoParado) return const SizedBox.shrink();

    if (aberta != null) {
      final descricao = aberta.descricao ?? '';
      return Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: esquema.primary, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(iconeDoMotivo(aberta.motivo), size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Parado: ${nomeDoMotivo(aberta.motivo, config.motivos)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              if (descricao.isNotEmpty)
                Text(descricao, style: TextStyle(fontSize: 15, color: cores.textoFraco)),
              const SizedBox(height: 4),
              Text(
                'Desde as ${horaTexto(aberta.inicioEm)}  •  há ${duracaoTexto(aberta.duracao(agora))}',
                style: estiloNumero(16, peso: FontWeight.w500, cor: cores.textoFraco),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => retomarViagem(context, ref, esqueceu: true),
                      child: const Text('Esqueci de retomar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => retomarViagem(context, ref),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Retomar viagem'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final desde = dados.fimDoUltimoDescanso;
    final rodando = desde == null ? null : agora.difference(desde);
    final limite = config.limiteMinutos;
    final passou = rodando != null && limite != null && rodando.inMinutes > limite;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: passou ? cores.atencaoFundo : esquema.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(passou ? Icons.warning_amber_rounded : Icons.route_outlined, color: passou ? cores.atencao : null),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rodando == null ? 'Rodando' : 'Sem descanso há ${duracaoTexto(rodando)}',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: passou ? cores.atencao : null),
                ),
                Text(
                  desde == null
                      ? 'Registre refeição, descanso ou pernoite para contar o tempo sem descanso.'
                      : 'Último descanso terminou ${dataTexto(desde) == dataTexto(agora) ? 'às' : 'em ${diaMes(desde)} às'} '
                            '${horaTexto(desde)}${limite == null ? '' : '. Limite da empresa: ${limiteTexto(limite)}'}.',
                  style: TextStyle(fontSize: 14, color: passou ? cores.atencao : cores.textoFraco),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
