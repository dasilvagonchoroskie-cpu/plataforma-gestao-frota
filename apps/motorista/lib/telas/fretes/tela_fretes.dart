import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/comuns.dart';
import '../../dados/dados.dart';
import 'detalhe_frete.dart';
import 'form_frete.dart';

class TelaFretes extends ConsumerWidget {
  const TelaFretes({super.key});

  void _novo(BuildContext context) => Navigator.push(context, MaterialPageRoute(builder: (_) => const FormFrete()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dados = assistirDados(ref);
    final grupos = agruparPorMes<Frete>(dados.fretes, (f) => f.dataCarga);

    return Scaffold(
      appBar: AppBar(title: const Text('Fretes')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'novo_frete',
        onPressed: () => _novo(context),
        icon: const Icon(Icons.add),
        label: const Text('Novo frete'),
      ),
      body: ListView(
        children: [
          const TopoCaminhao(),
          if (dados.fretes.isEmpty)
            EstadoVazio(
              icone: Icons.local_shipping_outlined,
              titulo: 'Nenhum frete anotado',
              texto: 'Anote a carga quando carregar: origem, destino, peso e o adiantamento. '
                  'O saldo e o peso da descarga você completa depois.',
              acao: FilledButton.icon(
                onPressed: () => _novo(context),
                icon: const Icon(Icons.add),
                label: const Text('Anotar o primeiro frete'),
              ),
            )
          else ...[
            for (final g in grupos) ...[
              CabecalhoMes(titulo: g.titulo, resumo: reais(g.itens.fold<double>(0, (s, f) => s + f.freteRealCentavos))),
              for (var i = 0; i < g.itens.length; i++) ...[
                if (i > 0) const Divider(indent: 20, endIndent: 20),
                LinhaFrete(frete: g.itens[i], dados: dados),
              ],
            ],
            espacoFinalLista,
          ],
        ],
      ),
    );
  }
}

class LinhaFrete extends StatelessWidget {
  const LinhaFrete({super.key, required this.frete, required this.dados});
  final Frete frete;
  final EstadoDados dados;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    final f = frete;
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetalheFrete(idFrete: f.id))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 20, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ColunaData(f.dataCarga),
            const SizedBox(width: 12),
            const Padding(padding: EdgeInsets.only(top: 6), child: MarcadorTrajeto(altura: 14)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.origem, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(f.destino, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  if (f.embarcador.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(f.embarcador, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: cores.textoFraco)),
                    ),
                  const SizedBox(height: 4),
                  MarcasLancamento(
                    pendente: dados.estaPendente(Tabelas.fretes, f.id),
                    ajustado: f.ajustado,
                    placa: dados.placaDe(f.caminhaoId),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(reais(f.freteRealCentavos), style: estiloNumero(18)),
                const SizedBox(height: 6),
                if (f.aguardandoSaldo && f.adiantamentoCentavos > 0)
                  const Etiqueta('Aguardando saldo')
                else if (f.freteRealCentavos <= 0)
                  const Etiqueta('Sem pagamento')
                else
                  Text('sua parte ${reais(f.minhaParteCentavos)}', style: TextStyle(fontSize: 13.5, color: cores.textoFraco)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
