import 'package:flutter/material.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../dados/equipe.dart';
import '../telas/lancamentos/detalhe_lancamento.dart';

void abrirLancamento(BuildContext context, String tabela, String id) => Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => TelaDetalheLancamento(tabela: tabela, id: id),
  ),
);

/// Moldura comum das linhas de lançamento: data, texto e valor à direita.
class _Linha extends StatelessWidget {
  const _Linha({
    required this.data,
    required this.titulo,
    this.subtitulo,
    required this.quem,
    required this.valor,
    this.abaixoDoValor,
    this.marcas = const [],
    this.aoTocar,
    this.inicioExtra,
  });

  final DateTime data;
  final String titulo;
  final String? subtitulo;
  final String quem;
  final String valor;
  final Widget? abaixoDoValor;
  final List<Widget> marcas;
  final VoidCallback? aoTocar;
  final Widget? inicioExtra;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    return InkWell(
      onTap: aoTocar,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ColunaData(data),
            const SizedBox(width: 12),
            ?inicioExtra,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600),
                  ),
                  if (subtitulo != null && subtitulo!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitulo!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, color: cores.textoFraco),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (quem.isNotEmpty)
                        Text(
                          quem,
                          style: TextStyle(fontSize: 13.5, color: cores.textoFraco, fontWeight: FontWeight.w500),
                        ),
                      ...marcas,
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(valor, style: estiloNumero(18)),
                if (abaixoDoValor != null) ...[const SizedBox(height: 6), abaixoDoValor!],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _quem(Equipe e, String motoristaId, String? caminhaoId) {
  final nome = e.nomeMotorista(motoristaId);
  final placa = e.placa(caminhaoId);
  if (placa.isEmpty) return nome;
  return nome.isEmpty ? placaTexto(placa) : '$nome  ·  ${placaTexto(placa)}';
}

const _corrigido = Etiqueta('Corrigido');

class ItemFrete extends StatelessWidget {
  const ItemFrete({super.key, required this.frete, required this.equipe});
  final Frete frete;
  final Equipe equipe;

  @override
  Widget build(BuildContext context) {
    final f = frete;
    final cores = context.cores;
    return _Linha(
      data: f.dataCarga,
      inicioExtra: const Padding(padding: EdgeInsets.only(top: 5, right: 10), child: MarcadorTrajeto(altura: 12)),
      titulo: '${f.origem}  –  ${f.destino}',
      subtitulo: f.embarcador,
      quem: _quem(equipe, f.motoristaId, f.caminhaoId),
      marcas: [if (f.ajustado) _corrigido],
      valor: reais(f.freteRealCentavos),
      abaixoDoValor: f.aguardandoSaldo && f.adiantamentoCentavos > 0
          ? const Etiqueta('Aguardando saldo')
          : (f.freteRealCentavos <= 0
                ? const Etiqueta('Sem pagamento')
                : Text(
                    'comissão ${reais(f.minhaParteCentavos)}',
                    style: TextStyle(fontSize: 13, color: cores.textoFraco),
                  )),
      aoTocar: () => abrirLancamento(context, 'fretes', f.id),
    );
  }
}

class ItemAbastecimento extends StatelessWidget {
  const ItemAbastecimento({super.key, required this.abastecimento, required this.equipe});
  final Abastecimento abastecimento;
  final Equipe equipe;

  @override
  Widget build(BuildContext context) {
    final a = abastecimento;
    final cores = context.cores;
    final media = a.pontoDePartida ? null : mediaDaLinha(equipe.abastecimentos, a).media;
    final lugar = [a.cidade, a.posto].where((t) => t.trim().isNotEmpty).join(' · ');
    return _Linha(
      data: a.data,
      titulo: a.pontoDePartida
          ? 'Km inicial ${semCasas(a.kmOdometro)}'
          : '${umaCasa(a.litros)} L  ·  km ${semCasas(a.kmOdometro)}',
      subtitulo: a.pontoDePartida ? 'Ponto de partida da média' : lugar,
      quem: _quem(equipe, a.motoristaId, a.caminhaoId),
      marcas: [
        if (a.ajustado) _corrigido,
        if (!a.tanqueCheio && !a.pontoDePartida) const Etiqueta('Não encheu', atencao: false),
      ],
      valor: a.pontoDePartida ? '—' : reais(a.valorCentavos),
      abaixoDoValor: media == null
          ? null
          : Text('${umaCasa(media)} km/L', style: TextStyle(fontSize: 13, color: cores.textoFraco)),
      aoTocar: a.pontoDePartida ? null : () => abrirLancamento(context, 'abastecimentos', a.id),
    );
  }
}

class ItemGasto extends StatelessWidget {
  const ItemGasto({super.key, required this.gasto, required this.equipe});
  final Gasto gasto;
  final Equipe equipe;

  @override
  Widget build(BuildContext context) {
    final g = gasto;
    return _Linha(
      data: g.data,
      titulo: g.categoriaNome,
      subtitulo: g.observacao,
      quem: _quem(equipe, g.motoristaId, g.caminhaoId),
      marcas: [if (g.ajustado) _corrigido],
      valor: reais(g.valorCentavos),
      aoTocar: () => abrirLancamento(context, 'gastos_viagem', g.id),
    );
  }
}

class ItemVale extends StatelessWidget {
  const ItemVale({super.key, required this.vale, required this.equipe});
  final Vale vale;
  final Equipe equipe;

  @override
  Widget build(BuildContext context) {
    final v = vale;
    return _Linha(
      data: v.data,
      titulo: (v.observacao ?? '').trim().isEmpty ? 'Vale' : v.observacao!,
      quem: equipe.nomeMotorista(v.motoristaId),
      marcas: [if (v.ajustado) _corrigido],
      valor: reais(v.valorCentavos),
      aoTocar: () => abrirLancamento(context, 'vales', v.id),
    );
  }
}

/// Lista com cabeçalho por mês e um aviso quando está vazia.
class ListaPorMes<T> extends StatelessWidget {
  const ListaPorMes({
    super.key,
    required this.itens,
    required this.data,
    required this.valor,
    required this.item,
    required this.vazio,
  });

  final List<T> itens;
  final DateTime Function(T) data;
  final num Function(T) valor;
  final Widget Function(T) item;
  final String vazio;

  @override
  Widget build(BuildContext context) {
    if (itens.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Text(vazio, style: TextStyle(fontSize: 16, color: context.cores.textoFraco)),
      );
    }
    final grupos = agruparPorMes<T>(itens, data);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final g in grupos) ...[
          CabecalhoMes(titulo: g.titulo, resumo: reais(g.itens.fold<num>(0, (s, e) => s + valor(e)))),
          for (var i = 0; i < g.itens.length; i++) ...[
            if (i > 0) const Divider(indent: 16, endIndent: 16, height: 1),
            item(g.itens[i]),
          ],
        ],
      ],
    );
  }
}
