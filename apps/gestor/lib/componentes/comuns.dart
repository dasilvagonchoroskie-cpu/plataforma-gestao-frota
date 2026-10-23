import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visual/visual.dart';

import '../dados/equipe.dart';
import '../dados/provedores.dart';
import '../servidor/servidor.dart';

/// Tela larga (computador ou tablet deitado): menu lateral e mais colunas.
bool telaLarga(BuildContext context) => MediaQuery.sizeOf(context).width >= 900;

/// Os dados da empresa já carregados (as telas internas só abrem depois).
Equipe assistirEquipe(WidgetRef ref) => ref.watch(equipeProvider).requireValue;

/// Conteúdo centralizado com largura máxima, para não esticar no monitor.
class Centro extends StatelessWidget {
  const Centro({super.key, required this.child, this.largura = 1100});
  final Widget child;
  final double largura;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => Align(
      alignment: Alignment.topCenter,
      child: SizedBox(width: c.maxWidth.isFinite && c.maxWidth < largura ? c.maxWidth : largura, child: child),
    ),
  );
}

/// Lista rolável centralizada (o padrão das telas do painel).
class ListaCentral extends StatelessWidget {
  const ListaCentral({super.key, required this.children, this.largura = 1100, this.padding});
  final List<Widget> children;
  final double largura;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => ListView(
    padding: padding ?? const EdgeInsets.only(bottom: 96),
    children: [for (final c in children) Centro(largura: largura, child: c)],
  );
}

/// Faz uma ação na nuvem mostrando "aguarde" e o erro em português.
/// Devolve true se deu certo.
Future<bool> executar(BuildContext context, Future<void> Function() acao, {String? sucesso}) async {
  final mensageiro = ScaffoldMessenger.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(
        child: Card(
          child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
        ),
      ),
    ),
  );
  final navegador = Navigator.of(context, rootNavigator: true);
  try {
    await acao();
    navegador.pop();
    if (sucesso != null) {
      mensageiro
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(sucesso)));
    }
    return true;
  } catch (e) {
    navegador.pop();
    final erro = traduzirErro(e);
    mensageiro
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(erro.mensagem), duration: const Duration(seconds: 6)));
    return false;
  }
}

/// Pergunta simples de sim ou não.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String texto,
  String botao = 'Confirmar',
  bool perigo = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text(texto, style: const TextStyle(fontSize: 16, height: 1.35)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: perigo ? FilledButton.styleFrom(backgroundColor: ctx.cores.negativo) : null,
          child: Text(botao),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Botão de atualizar da barra de cima (busca de novo na nuvem).
class BotaoAtualizar extends ConsumerWidget {
  const BotaoAtualizar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    tooltip: 'Atualizar',
    icon: const Icon(Icons.refresh),
    onPressed: () =>
        executar(context, () => ref.read(equipeProvider.notifier).recarregar(), sucesso: 'Dados atualizados.'),
  );
}

/// Cartão de número do painel (faturamento, diesel...).
class CartaoNumero extends StatelessWidget {
  const CartaoNumero({
    super.key,
    required this.rotulo,
    required this.valor,
    this.detalhe,
    this.icone,
    this.cor,
    this.destaque = false,
    this.aoTocar,
    this.categoria = Categoria.neutro,
  });

  final String rotulo;
  final String valor;
  final String? detalhe;
  final IconData? icone;

  /// Cor do ícone (um círculo colorido para cada número, como no cartaz).
  final Categoria categoria;
  final Color? cor;
  final bool destaque;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    final esquema = Theme.of(context).colorScheme;
    final fundo = destaque ? cores.placa : esquema.surfaceContainerLow;
    final texto = destaque ? cores.placaTexto : null;
    return Card(
      margin: EdgeInsets.zero,
      color: fundo,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: destaque ? fundo : cores.divisor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: aoTocar,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (icone != null) ...[
                    if (destaque)
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.18)),
                        child: Icon(icone, size: 19, color: texto),
                      )
                    else
                      IconeCategoria(icone!, categoria, tamanho: 34),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      rotulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14.5, color: texto ?? cores.textoFraco, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  valor,
                  style: estiloNumero(26, peso: FontWeight.w700, cor: texto ?? cor),
                ),
              ),
              if (detalhe != null && detalhe!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  detalhe!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    color: texto?.withValues(alpha: 0.85) ?? cores.textoFraco,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Grade de cartões que se ajusta à largura (1 a 4 colunas).
class GradeCartoes extends StatelessWidget {
  const GradeCartoes({super.key, required this.cartoes, this.larguraMinima = 220});
  final List<Widget> cartoes;
  final double larguraMinima;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final colunas = (c.maxWidth / larguraMinima).floor().clamp(1, 4);
      const espaco = 12.0;
      final largura = (c.maxWidth - espaco * (colunas - 1)) / colunas;
      return Wrap(
        spacing: espaco,
        runSpacing: espaco,
        children: [for (final w in cartoes) SizedBox(width: largura, child: w)],
      );
    },
  );
}

/// Escolha de um item numa lista (motorista, caminhão, embarcador), com
/// "Todos" quando [todos] não é nulo.
class Escolha<T> extends StatelessWidget {
  const Escolha({
    super.key,
    required this.rotulo,
    required this.valor,
    required this.itens,
    required this.aoMudar,
    this.todos,
    this.largura = 240,
  });

  final String rotulo;
  final T? valor;
  final Map<T, String> itens;
  final ValueChanged<T?> aoMudar;
  final String? todos;
  final double largura;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: largura,
    child: DropdownButtonFormField<T?>(
      key: ValueKey('$rotulo|$valor|${itens.length}'),
      initialValue: itens.containsKey(valor) ? valor : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: rotulo, isDense: true),
      items: [
        if (todos != null) DropdownMenuItem<T?>(value: null, child: Text(todos!)),
        for (final e in itens.entries)
          DropdownMenuItem<T?>(
            value: e.key,
            child: Text(e.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: aoMudar,
    ),
  );
}

/// Faixa com o período escolhido (vale para painel, lançamentos e relatórios).
class FaixaPeriodo extends ConsumerWidget {
  const FaixaPeriodo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final escolha = ref.watch(periodoProvider);
    return SeletorPeriodo(escolha: escolha, aoMudar: ref.read(periodoProvider.notifier).escolher);
  }
}

/// Selo pequeno colorido (status).
class Selo extends StatelessWidget {
  const Selo(this.texto, {super.key, this.cor});
  final String texto;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    final c = cor ?? context.cores.textoFraco;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.6)),
      ),
      child: Text(
        texto,
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c),
      ),
    );
  }
}
