import 'package:flutter/material.dart';

import 'tema.dart';

/// Ícone colorido num círculo (o jeito do cartaz da plataforma).
class IconeCategoria extends StatelessWidget {
  const IconeCategoria(this.icone, this.categoria, {super.key, this.tamanho = 44, this.cheio = false});

  final IconData icone;
  final Categoria categoria;
  final double tamanho;

  /// Círculo cheio com o ícone escuro (o destaque); senão, cor clarinha.
  final bool cheio;

  @override
  Widget build(BuildContext context) {
    final cor = categoria.de(context);
    final escuro = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cheio ? cor : cor.withValues(alpha: escuro ? 0.16 : 0.12),
      ),
      child: Icon(
        icone,
        size: tamanho * 0.54,
        color: cheio ? (escuro ? Paleta.marinho : Colors.white) : cor,
      ),
    );
  }
}

/// Botão grande do Início do motorista: ícone colorido, nome, uma linha do
/// que tem ali e a seta.
class ItemMenu extends StatelessWidget {
  const ItemMenu({
    super.key,
    required this.icone,
    required this.categoria,
    required this.titulo,
    this.subtitulo,
    this.aoTocar,
    this.destaque,
  });

  final IconData icone;
  final Categoria categoria;
  final String titulo;
  final String? subtitulo;
  final VoidCallback? aoTocar;

  /// Etiqueta à direita (ex.: "parado", "2 não enviados").
  final String? destaque;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: aoTocar,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              IconeCategoria(icone, categoria, tamanho: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                    if (subtitulo != null && subtitulo!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitulo!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14.5, color: cores.textoFraco, height: 1.25),
                        ),
                      ),
                  ],
                ),
              ),
              if (destaque != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: categoria.de(context).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    destaque!,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: categoria.de(context)),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: cores.textoFraco),
            ],
          ),
        ),
      ),
    );
  }
}

/// Como o app aparece: escuro (o padrão, igual ao cartaz), claro (melhor no
/// sol forte) ou igual ao celular.
enum PreferenciaTema {
  escuro('Escuro', ThemeMode.dark),
  claro('Claro', ThemeMode.light),
  celular('Igual ao celular', ThemeMode.system);

  const PreferenciaTema(this.rotulo, this.modo);
  final String rotulo;
  final ThemeMode modo;

  static PreferenciaTema deTexto(String? t) =>
      PreferenciaTema.values.where((p) => p.name == t).firstOrNull ?? PreferenciaTema.escuro;
}

/// Escolha da aparência nas Configurações dos dois apps.
class EscolhaTema extends StatelessWidget {
  const EscolhaTema({super.key, required this.valor, required this.aoMudar});

  final PreferenciaTema valor;
  final ValueChanged<PreferenciaTema> aoMudar;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<PreferenciaTema>(
              showSelectedIcon: false,
              segments: [
                for (final p in PreferenciaTema.values)
                  ButtonSegment(
                    value: p,
                    label: Text(p == PreferenciaTema.celular ? 'Do celular' : p.rotulo),
                    icon: Icon(switch (p) {
                      PreferenciaTema.escuro => Icons.dark_mode_outlined,
                      PreferenciaTema.claro => Icons.light_mode_outlined,
                      PreferenciaTema.celular => Icons.smartphone,
                    }),
                  ),
              ],
              selected: {valor},
              onSelectionChanged: (s) => aoMudar(s.first),
            ),
            const SizedBox(height: 6),
            Text(
              'O claro se lê melhor no sol forte.',
              style: TextStyle(fontSize: 13.5, color: context.cores.textoFraco),
            ),
          ],
        ),
      );
}
