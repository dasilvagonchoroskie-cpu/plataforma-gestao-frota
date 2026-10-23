import 'package:flutter/material.dart';

import 'tema.dart';

/// Linha de conta: rotulo a esquerda, valor a direita.
class LinhaValor extends StatelessWidget {
  const LinhaValor({
    super.key,
    required this.rotulo,
    required this.valor,
    this.detalhe,
    this.corValor,
    this.destaque = false,
    this.corDetalhe,
  });

  final String rotulo;
  final String valor;
  final String? detalhe;
  final Color? corValor;
  final bool destaque;
  final Color? corDetalhe;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rotulo,
                  style: TextStyle(fontSize: destaque ? 17 : 16, fontWeight: destaque ? FontWeight.w600 : FontWeight.w400),
                ),
                if (detalhe != null && detalhe!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(detalhe!, style: TextStyle(fontSize: 13.5, color: corDetalhe ?? cores.textoFraco, height: 1.3)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(valor, style: estiloNumero(destaque ? 21 : 18, cor: corValor)),
        ],
      ),
    );
  }
}

/// Titulo de um bloco dentro da tela.
class TituloSecao extends StatelessWidget {
  const TituloSecao(this.texto, {super.key, this.acao, this.espacoAcima = 28});

  final String texto;
  final Widget? acao;
  final double espacoAcima;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: espacoAcima, bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(texto, style: context.textos.titleMedium)),
          ?acao,
        ],
      ),
    );
  }
}

/// Faixa amarela de atencao (como a faixa da estrada).
class Aviso extends StatelessWidget {
  const Aviso({super.key, required this.texto, this.titulo, this.icone = Icons.info_outline});

  final String? titulo;
  final String texto;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    return Container(
      decoration: BoxDecoration(
        color: cores.atencaoFundo,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: Paleta.amareloFaixa, width: 5)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: cores.atencao, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (titulo != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(titulo!, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: cores.atencao)),
                  ),
                Text(texto, style: TextStyle(fontSize: 15, color: cores.atencao, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Explicacao curta em cinza.
class Nota extends StatelessWidget {
  const Nota(this.texto, {super.key, this.cor});
  final String texto;
  final Color? cor;

  @override
  Widget build(BuildContext context) =>
      Text(texto, style: TextStyle(fontSize: 14.5, height: 1.35, color: cor ?? context.cores.textoFraco));
}

/// Tela vazia: diz o que fazer.
class EstadoVazio extends StatelessWidget {
  const EstadoVazio({super.key, required this.icone, required this.titulo, required this.texto, this.acao});

  final IconData icone;
  final String titulo;
  final String texto;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 120),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 44, color: cores.textoFraco),
          const SizedBox(height: 16),
          Text(titulo, style: context.textos.titleLarge),
          const SizedBox(height: 8),
          Text(texto, style: TextStyle(fontSize: 16, height: 1.4, color: cores.textoFraco)),
          if (acao != null) ...[const SizedBox(height: 20), acao!],
        ],
      ),
    );
  }
}

/// Cabecalho de grupo por mes nas listas.
class CabecalhoMes extends StatelessWidget {
  const CabecalhoMes({super.key, required this.titulo, required this.resumo});

  final String titulo;
  final String resumo;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: Text(titulo, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cores.textoFraco))),
          const SizedBox(width: 8),
          Flexible(child: Text(resumo, textAlign: TextAlign.end, style: estiloNumero(16, cor: cores.textoFraco))),
        ],
      ),
    );
  }
}

/// Pergunta antes de apagar.
Future<bool> confirmarExclusao(BuildContext context, {required String titulo, required String detalhe}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text(detalhe, style: const TextStyle(fontSize: 16)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: ctx.cores.negativo),
          child: const Text('Apagar'),
        ),
      ],
    ),
  );
  return r ?? false;
}

void mostrarMensagem(BuildContext context, String texto) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));
}

/// Botao principal fixo no rodape dos formularios.
class RodapeBotao extends StatelessWidget {
  const RodapeBotao({super.key, required this.texto, required this.aoTocar, this.icone});

  final String texto;
  final VoidCallback? aoTocar;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: context.cores.divisor)),
        ),
        child: SizedBox(
          width: double.infinity,
          child: icone == null
              ? FilledButton(onPressed: aoTocar, child: Text(texto))
              : FilledButton.icon(onPressed: aoTocar, icon: Icon(icone), label: Text(texto)),
        ),
      ),
    );
  }
}
