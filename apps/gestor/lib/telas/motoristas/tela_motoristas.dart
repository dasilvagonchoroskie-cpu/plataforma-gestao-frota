import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:share_plus/share_plus.dart';
import 'package:visual/visual.dart';

import '../../componentes/comuns.dart';
import '../../dados/equipe.dart';
import '../../dados/modelos.dart';
import '../../dados/provedores.dart';
import '../casca.dart';
import 'detalhe_motorista.dart';

/// Motoristas: código da empresa, pedidos de entrada e a lista.
class TelaMotoristas extends ConsumerWidget {
  const TelaMotoristas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = assistirEquipe(ref);
    final agora = ref.read(relogioProvider)();
    final pendentes = e.pedidosPendentes;
    final ativos = e.motoristas.where((m) => m.ativo).toList();
    final desligados = e.motoristas.where((m) => !m.ativo).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Motoristas'), actions: acoesPadrao(context, ref)),
      body: ListaCentral(
        largura: 900,
        children: [
          const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 0), child: CartaoCodigo()),
          if (pendentes.isNotEmpty) ...[
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: TituloSecao('Pedidos para entrar')),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Nota(
                'Confira o nome e o CPF antes de aprovar. Quem você aprovar passa a enviar os lançamentos para o painel.',
              ),
            ),
            for (final p in pendentes) _CartaoPedido(pedido: p, agora: agora),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TituloSecao('Na empresa (${ativos.length})'),
          ),
          if (ativos.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Nota('Nenhum motorista ainda. Mande o código acima para eles pelo WhatsApp.'),
            ),
          for (final m in ativos) LinhaMotorista(motorista: m, equipe: e, agora: agora),
          if (desligados.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TituloSecao('Desligados (${desligados.length})'),
            ),
            for (final m in desligados) LinhaMotorista(motorista: m, equipe: e, agora: agora),
          ],
        ],
      ),
    );
  }
}

/// Código de 6 letras que o motorista digita no app para pedir entrada.
class CartaoCodigo extends ConsumerWidget {
  const CartaoCodigo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = assistirEquipe(ref);
    final cores = context.cores;
    final codigo = e.empresa.codigoEntrada ?? '—';
    final texto =
        'Para entrar na ${e.empresa.nome} pelo app Frota Motorista: crie a sua conta e, quando o app '
        'pedir o código da empresa, digite $codigo.';

    Future<void> trocar() async {
      final ok = await confirmar(
        context,
        titulo: 'Gerar outro código?',
        texto: 'O código $codigo para de funcionar na hora. Quem já está na empresa continua normalmente.',
        botao: 'Gerar outro',
      );
      if (!ok || !context.mounted) return;
      await executar(context, () async {
        final novo = await ref.read(equipeProvider.notifier).gerarNovoCodigo();
        if (context.mounted) mostrarMensagem(context, 'Código novo: $novo');
      });
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cores.divisor),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Código da empresa', style: TextStyle(fontSize: 14, color: cores.textoFraco)),
                const SizedBox(height: 4),
                SelectableText(codigo, style: estiloNumero(34, peso: FontWeight.w700).copyWith(letterSpacing: 6)),
                Text(
                  'O motorista digita no app para pedir entrada.',
                  style: TextStyle(fontSize: 13.5, color: cores.textoFraco),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: texto));
                    if (context.mounted) mostrarMensagem(context, 'Recado copiado. Cole no WhatsApp do motorista.');
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copiar recado'),
                ),
                OutlinedButton.icon(
                  onPressed: () => SharePlus.instance.share(ShareParams(text: texto)),
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Enviar'),
                ),
                TextButton(onPressed: trocar, child: const Text('Gerar outro')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CartaoPedido extends ConsumerWidget {
  const _CartaoPedido({required this.pedido, required this.agora});
  final PedidoEntrada pedido;
  final DateTime agora;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = pedido;
    final cores = context.cores;
    Future<void> decidir(bool aprovar) async {
      if (!aprovar) {
        final ok = await confirmar(
          context,
          titulo: 'Recusar ${p.nome}?',
          texto: 'Ele não entra na empresa. Se for engano, ele pode digitar o código de novo.',
          botao: 'Recusar',
          perigo: true,
        );
        if (!ok || !context.mounted) return;
      }
      await executar(
        context,
        () => ref.read(equipeProvider.notifier).decidirEntrada(p.id, aprovar),
        sucesso: aprovar ? '${p.nome} entrou na empresa.' : 'Pedido recusado.',
      );
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      elevation: 0,
      color: cores.atencaoFundo,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Wrap(
          spacing: 16,
          runSpacing: 10,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(p.nome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                SelectableText('CPF ${cpfTexto(p.cpf)}  ·  ${p.email}', style: const TextStyle(fontSize: 14.5)),
                Text(
                  'Pediu ${quandoTexto(p.pedidoEm, agora)}',
                  style: TextStyle(fontSize: 13.5, color: cores.textoFraco),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(onPressed: () => decidir(false), child: const Text('Recusar')),
                FilledButton.icon(
                  onPressed: () => decidir(true),
                  icon: const Icon(Icons.check),
                  label: const Text('Aprovar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class LinhaMotorista extends StatelessWidget {
  const LinhaMotorista({super.key, required this.motorista, required this.equipe, required this.agora});
  final Motorista motorista;
  final Equipe equipe;
  final DateTime agora;

  @override
  Widget build(BuildContext context) {
    final m = motorista;
    final cores = context.cores;
    final caminhao = equipe.caminhaoAtual(m.id);
    final envio = equipe.ultimoEnvio(m);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: CircleAvatar(
        backgroundColor: m.ativo ? cores.placa : cores.divisor,
        foregroundColor: m.ativo ? cores.placaTexto : cores.textoFraco,
        child: Text(m.nome.isEmpty ? '?' : m.nome.trim()[0].toUpperCase()),
      ),
      title: Text(m.nome, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${caminhao == null ? 'sem caminhão' : placaTexto(caminhao.placa)}  ·  último envio ${quandoTexto(envio, agora)}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TelaDetalheMotorista(motoristaId: m.id))),
    );
  }
}
