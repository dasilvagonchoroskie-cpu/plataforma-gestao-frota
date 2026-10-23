import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/comuns.dart';
import '../../dados/dados.dart';
import '../../relatorio/compartilhar.dart';
import 'form_frete.dart';

class DetalheFrete extends ConsumerStatefulWidget {
  const DetalheFrete({super.key, required this.idFrete});
  final String idFrete;

  @override
  ConsumerState<DetalheFrete> createState() => _DetalheFreteState();
}

class _DetalheFreteState extends ConsumerState<DetalheFrete> {
  bool _gerando = false;

  @override
  Widget build(BuildContext context) {
    final dados = assistirDados(ref);
    final f = dados.freteComId(widget.idFrete);
    final cores = context.cores;

    if (f == null) return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());

    final viagem = dados.dadosDaViagem(f);
    final r = viagem.resultado;
    final contratado = f.valorContratadoCentavos;
    final dif = f.diferencaDoContratadoCentavos;
    final quebra = f.quebraKg;
    final ajustes = dados.ajustesDe(f.id);

    Future<void> apagar() async {
      final ok = await confirmarExclusao(
        context,
        titulo: 'Apagar este frete?',
        detalhe: '${f.rota}, carga de ${dataTexto(f.dataCarga)}. O seu patrão vai ver que foi apagado.',
      );
      if (!ok || !context.mounted) return;
      final mensageiro = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      await ref.read(dadosProvider.notifier).apagarFrete(f);
      mensageiro.showSnackBar(const SnackBar(content: Text('Frete apagado.')));
    }

    Future<void> enviar() async {
      setState(() => _gerando = true);
      try {
        await gerarEEnviarPdf(viagem);
      } catch (e) {
        if (context.mounted) mostrarMensagem(context, 'Não deu para montar o acerto agora. Tente de novo.');
      } finally {
        if (mounted) setState(() => _gerando = false);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Frete'),
        actions: [
          if (ajustes.isEmpty) ...[
            IconButton(
              tooltip: 'Mudar',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FormFrete(editando: f))),
            ),
            IconButton(tooltip: 'Apagar', icon: const Icon(Icons.delete_outline), onPressed: apagar),
          ],
          const SizedBox(width: 4),
        ],
      ),
      bottomNavigationBar: RodapeBotao(
        texto: _gerando ? 'Montando o PDF...' : 'Enviar acerto da viagem',
        icone: Icons.ios_share,
        aoTocar: _gerando ? null : enviar,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          AvisoAjustado(ajustes: ajustes),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(padding: EdgeInsets.only(top: 7), child: MarcadorTrajeto(altura: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.origem, style: context.textos.titleLarge),
                    const SizedBox(height: 8),
                    Text(f.destino, style: context.textos.titleLarge),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Carga de ${dataTexto(f.dataCarga)}${f.embarcador.trim().isNotEmpty ? ', ${f.embarcador.trim()}' : ''}',
            style: TextStyle(fontSize: 15.5, color: cores.textoFraco),
          ),
          const SizedBox(height: 6),
          MarcasLancamento(
            pendente: dados.estaPendente(Tabelas.fretes, f.id),
            ajustado: f.ajustado,
            placa: dados.placaDe(f.caminhaoId),
          ),
          const SizedBox(height: 14),
          Placa(
            rotulo: 'Sua parte neste frete',
            valor: reais(f.minhaParteCentavos),
            detalhe:
                '${percentualTexto(f.percentualComissao)}% sobre ${reais(f.baseComissaoCentavos)}'
                '${f.comissaoSobreBruto ? ' (frete + pedágio)' : ''}',
            tamanhoValor: 40,
          ),
          if (f.aguardandoSaldo && ajustes.isEmpty) ...[
            const SizedBox(height: 12),
            const Aviso(
              icone: Icons.hourglass_bottom,
              titulo: 'Aguardando o saldo',
              texto: 'Quando o saldo cair, toque no lápis lá em cima e anote o valor.',
            ),
          ],
          const TituloSecao('Pagamento'),
          if (contratado > 0)
            LinhaValor(
              rotulo: 'Valor contratado',
              valor: reais(contratado),
              detalhe: '${toneladas(f.pesoCargaKg)} t × ${reais(f.valorToneladaCentavos)}',
            ),
          LinhaValor(rotulo: 'Adiantamento', valor: reais(f.adiantamentoCentavos)),
          LinhaValor(
            rotulo: 'Saldo',
            valor: f.saldoCentavos > 0 ? reais(f.saldoCentavos) : 'em aberto',
            corValor: f.saldoCentavos > 0 ? null : cores.atencao,
          ),
          const Divider(height: 18),
          LinhaValor(rotulo: 'Frete real (caiu na conta)', valor: reais(f.freteRealCentavos), destaque: true),
          if (f.pedagioCentavos > 0)
            LinhaValor(rotulo: 'Pedágio no cartão ou tag', valor: reais(f.pedagioCentavos), detalhe: 'Fora do frete'),
          if (f.freteRealCentavos > 0 && contratado > 0 && !f.aguardandoSaldo)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Nota(
                dif.abs() < 1
                    ? 'Bateu certinho com o combinado.'
                    : (dif > 0
                          ? 'Entrou ${reais(dif)} a mais que o combinado. Confira.'
                          : 'A transportadora descontou ${reais(dif.abs())} do contratado '
                                '(INSS, SEST/SENAT, seguro, pedágio, quebra).'),
                cor: dif.abs() < 1 ? cores.positivo : (dif > 0 ? cores.atencao : null),
              ),
            ),
          if (f.pesoDescargaKg > 0 || quebra != null) ...[
            const TituloSecao('Descarga'),
            LinhaValor(rotulo: 'Carregou', valor: '${toneladas(f.pesoCargaKg)} t'),
            LinhaValor(rotulo: 'Descarregou', valor: '${toneladas(f.pesoDescargaKg)} t'),
            if (quebra != null) ...[
              LinhaValor(
                rotulo: 'Quebra',
                valor: '${semCasas(quebra)} kg',
                detalhe: 'Pelo valor da tonelada vale ${reais(f.valorQuebraIntegralCentavos)}',
                corValor: cores.atencao,
              ),
              LinhaValor(
                rotulo: 'Descontaram',
                valor: f.descontoQuebraCentavos > 0 ? reais(f.descontoQuebraCentavos) : 'nada',
              ),
            ],
          ],
          if (f.extras.values.any((v) => !extraVazio(v))) ...[
            const TituloSecao('Mais informações'),
            LinhasExtras(extras: f.extras, modalidade: dados.modalidade),
          ],
          const TituloSecao('Conta desta viagem'),
          Nota(
            'Diesel, gastos e vales lançados de ${dataTexto(viagem.periodo.inicio)} a '
            '${dataTexto(viagem.periodo.fim)}, até a carga seguinte.',
          ),
          const SizedBox(height: 6),
          LinhaValor(rotulo: 'Frete que caiu na conta', valor: reais(r.totalFretes)),
          LinhaValor(
            rotulo: 'Diesel',
            valor: '$menos ${reais(r.totalAbastecimento)}',
            detalhe: plural(viagem.abastecimentos.length, 'abastecida', 'abastecidas'),
          ),
          LinhaValor(
            rotulo: 'Outros gastos',
            valor: '$menos ${reais(r.totalGastos)}',
            detalhe: plural(viagem.gastos.length, 'gasto', 'gastos'),
          ),
          LinhaValor(rotulo: 'Comissão do motorista', valor: '$menos ${reais(r.comissaoDoCaminhao)}'),
          const Divider(height: 18),
          LinhaValor(
            rotulo: r.sobraDoCaminhao >= 0 ? 'Sobrou para o caminhão' : 'Faltou',
            valor: reais(r.sobraDoCaminhao),
            destaque: true,
            corValor: r.sobraDoCaminhao >= 0 ? cores.positivo : (f.aguardandoSaldo ? cores.atencao : cores.negativo),
          ),
        ],
      ),
    );
  }
}
