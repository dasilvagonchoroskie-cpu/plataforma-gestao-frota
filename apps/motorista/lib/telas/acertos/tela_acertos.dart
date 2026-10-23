import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/comuns.dart';
import '../../relatorio/compartilhar.dart';

/// Os acertos que o patrão fechou (Baú e Sider): só para ver e mandar o PDF.
class TelaAcertos extends ConsumerWidget {
  const TelaAcertos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dados = assistirDados(ref);
    final cores = context.cores;
    return Scaffold(
      appBar: AppBar(title: const Text('Meus acertos')),
      body: dados.acertos.isEmpty
          ? const EstadoVazio(
              icone: Icons.request_quote_outlined,
              titulo: 'Nenhum acerto fechado ainda',
              texto: 'Quando o seu patrão fechar o acerto (comissão e descontos), ele aparece aqui.',
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                for (final a in dados.acertos)
                  ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(20, 6, 16, 6),
                    title: Text(a.periodoTexto, style: estiloNumero(17, peso: FontWeight.w600)),
                    subtitle: Text(
                      '${plural(a.quantidadeViagens, 'viagem', 'viagens')}  ·  comissão ${reais(a.comissaoCentavos)}',
                      style: const TextStyle(fontSize: 14.5),
                    ),
                    trailing: Text(
                      reais(a.paraReceberCentavos),
                      style: estiloNumero(18, cor: a.paraReceberCentavos < 0 ? cores.negativo : cores.positivo),
                    ),
                    onTap: () =>
                        Navigator.push(context, MaterialPageRoute(builder: (_) => DetalheAcerto(idAcerto: a.id))),
                  ),
              ],
            ),
    );
  }
}

class DetalheAcerto extends ConsumerStatefulWidget {
  const DetalheAcerto({super.key, required this.idAcerto});
  final String idAcerto;

  @override
  ConsumerState<DetalheAcerto> createState() => _DetalheAcertoState();
}

class _DetalheAcertoState extends ConsumerState<DetalheAcerto> {
  bool _gerando = false;

  @override
  Widget build(BuildContext context) {
    final dados = assistirDados(ref);
    final a = dados.acertoComId(widget.idAcerto);
    final cores = context.cores;
    if (a == null) return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    final relatorio = dados.dadosDoAcerto(a);

    Future<void> enviar() async {
      setState(() => _gerando = true);
      try {
        await gerarEEnviarPdf(relatorio);
      } catch (_) {
        if (context.mounted) mostrarMensagem(context, 'Não deu para montar o PDF agora. Tente de novo.');
      } finally {
        if (mounted) setState(() => _gerando = false);
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Acerto')),
      bottomNavigationBar: RodapeBotao(
        texto: _gerando ? 'Montando o PDF...' : 'Enviar PDF do acerto',
        icone: Icons.ios_share,
        aoTocar: _gerando ? null : enviar,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Placa(
            rotulo: a.paraReceberCentavos < 0 ? 'Você está devendo' : 'Você tem para receber',
            valor: reais(a.paraReceberCentavos),
            detalhe: a.periodoTexto,
            tipo: a.paraReceberCentavos < 0 ? TipoPlaca.vermelha : TipoPlaca.verde,
          ),
          const SizedBox(height: 10),
          LinhaValor(rotulo: 'Comissão', valor: '+ ${reais(a.comissaoCentavos)}', corValor: cores.positivo),
          for (final x in a.descontos)
            LinhaValor(rotulo: x.descricao, valor: '$menos ${reais(x.valorCentavos)}', corValor: cores.negativo),
          LinhaValor(
            rotulo: 'Vales',
            valor: a.descontaVales ? '$menos ${reais(a.valesCentavos)}' : reais(a.valesCentavos),
            detalhe: a.descontaVales ? 'Você já recebeu adiantado, então desconta' : 'Só histórico, não desconta',
            corValor: a.descontaVales ? cores.negativo : cores.textoFraco,
          ),
          LinhaValor(
            rotulo: 'Diesel e gastos',
            valor: a.descontaGastos
                ? '$menos ${reais(a.dieselCentavos + a.gastosCentavos)}'
                : reais(a.dieselCentavos + a.gastosCentavos),
            detalhe: a.descontaGastos ? 'Saem do seu bolso, então descontam' : 'A empresa paga, não descontam',
            corValor: a.descontaGastos ? cores.negativo : cores.textoFraco,
          ),
          if ((a.observacao ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Nota('Observação do patrão: ${a.observacao!.trim()}'),
          ],
          if (a.fechadoEm != null) ...[const SizedBox(height: 8), Nota('Fechado em ${dataHoraTexto(a.fechadoEm!)}.')],
          TituloSecao('Viagens do período (${relatorio.viagens.length})'),
          if (relatorio.viagens.isEmpty) const Nota('Nenhuma viagem anotada neste período.'),
          for (final v in relatorio.viagens)
            LinhaValor(
              rotulo: '${dataTexto(v.engateEm)}  ${v.rota}',
              valor: '${v.entregasQuantidade}',
              detalhe:
                  'Carreta ${placaTexto(v.placaCarreta)}'
                  '${v.entregasCidades.isEmpty ? '' : '  ·  ${v.entregasCidades.join(', ')}'}',
            ),
        ],
      ),
    );
  }
}
