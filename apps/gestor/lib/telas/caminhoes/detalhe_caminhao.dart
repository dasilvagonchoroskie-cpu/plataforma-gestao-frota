import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/comuns.dart';
import '../../componentes/itens.dart';
import '../../dados/provedores.dart';
import '../../relatorio/compartilhar.dart';
import 'tela_caminhoes.dart';

/// Um caminhão: custo por km, média de diesel, resultado e histórico.
class TelaDetalheCaminhao extends ConsumerWidget {
  const TelaDetalheCaminhao({super.key, required this.caminhaoId});
  final String caminhaoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = assistirEquipe(ref);
    final c = e.caminhao(caminhaoId);
    if (c == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EstadoVazio(
          icone: Icons.local_shipping_outlined,
          titulo: 'Caminhão não encontrado',
          texto: 'Atualize a tela.',
        ),
      );
    }
    final cores = context.cores;
    final escolha = ref.watch(periodoProvider);
    final periodo = escolha.periodoOuMes;
    final d = e.relatorio(periodo, caminhaoId: c.id);
    final r = d.resultado;
    final km = e.kmRodados(c.id, periodo);
    final media = mediaDoPeriodo(d.abastecimentos, e.abastecimentos);
    final litros = d.abastecimentos.fold<double>(0, (s, a) => s + a.litros);
    final custo = r.totalAbastecimento + r.totalGastos;
    final quem = e.motoristasNoCaminhao(c.id);
    final usos = e.usosDoCaminhao(c.id);

    Future<void> confirmarCaminhao() => executar(
      context,
      () => ref.read(equipeProvider.notifier).confirmarCaminhao(c.id),
      sucesso: 'Caminhão confirmado.',
    );

    Future<void> ativar() async {
      final ok = await confirmar(
        context,
        titulo: c.ativo ? 'Parar o caminhão ${placaTexto(c.placa)}?' : 'Voltar o caminhão ${placaTexto(c.placa)}?',
        texto: c.ativo
            ? 'Ele some da lista dos motoristas e libera uma vaga do plano. O histórico continua.'
            : 'Ele volta para a lista dos motoristas.',
        botao: c.ativo ? 'Parar' : 'Voltar',
      );
      if (ok && context.mounted) {
        await executar(context, () => ref.read(equipeProvider.notifier).ativarCaminhao(c.id, !c.ativo));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(placaTexto(c.placa)),
        actions: [
          const BotaoAtualizar(),
          IconButton(
            tooltip: 'Relatório em PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => executar(context, () => compartilharPdf(d)),
          ),
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => abrirFormCaminhao(context, caminhao: c),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListaCentral(
        largura: 900,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(
              children: [
                PlacaVeiculo(c.placa, tamanho: 22),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [
                          if (c.numeroFrota != null) 'Frota ${c.numeroFrota}',
                          c.modelo,
                          if (c.ano != null) '${c.ano}',
                        ].where((t) => t.isNotEmpty).join('  ·  '),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        quem.isEmpty ? 'Sem motorista agora' : 'Agora com ${quem.map((m) => m.nome).join(' e ')}',
                        style: TextStyle(color: quem.length > 1 ? cores.atencao : cores.textoFraco),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!c.confirmado)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Card(
                elevation: 0,
                color: cores.atencaoFundo,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Cadastrado por um motorista. Confira a placa e os dados.',
                        style: TextStyle(fontSize: 15.5),
                      ),
                      FilledButton(onPressed: confirmarCaminhao, child: const Text('Confirmar')),
                      OutlinedButton(
                        onPressed: () => abrirFormCaminhao(context, caminhao: c),
                        child: const Text('Corrigir'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          const FaixaPeriodo(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: GradeCartoes(
              cartoes: [
                CartaoNumero(
                  rotulo: 'Km rodados',
                  valor: km > 0 ? semCasas(km) : '—',
                  detalhe: km > 0 ? 'Pelo odômetro das abastecidas' : 'Precisa de abastecidas com km',
                  icone: Icons.speed,
                ),
                CartaoNumero(
                  rotulo: 'Média de diesel',
                  valor: media.media == null ? '—' : '${umaCasa(media.media!)} km/L',
                  detalhe: media.media == null
                      ? 'Precisa de dois tanques cheios'
                      : '${semCasas(media.km)} km com ${umaCasa(media.litros)} L',
                  icone: Icons.local_gas_station_outlined,
                ),
                CartaoNumero(
                  rotulo: 'Custo por km',
                  valor: km > 0 ? reais(custo / km) : '—',
                  detalhe: 'Diesel + gastos (${reais(custo)})',
                  icone: Icons.price_change_outlined,
                ),
                CartaoNumero(
                  rotulo: 'Faturamento',
                  valor: reais(r.totalFretes),
                  detalhe: km > 0
                      ? '${reais(r.totalFretes / km)} por km'
                      : plural(r.quantidadeFretes, 'frete', 'fretes'),
                  icone: Icons.trending_up,
                ),
                CartaoNumero(
                  rotulo: 'Resultado',
                  valor: reais(r.sobraDoCaminhao),
                  detalhe: 'Frete − diesel − gastos − comissão',
                  icone: Icons.savings_outlined,
                  destaque: true,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              children: [
                LinhaValor(
                  rotulo: 'Diesel',
                  valor: reais(r.totalAbastecimento),
                  detalhe: litros > 0 ? '${umaCasa(litros)} L' : null,
                ),
                LinhaValor(rotulo: 'Outros gastos', valor: reais(r.totalGastos)),
                LinhaValor(rotulo: 'Comissões', valor: reais(r.comissaoDoCaminhao)),
                if (r.fretesEmAberto > 0)
                  LinhaValor(
                    rotulo: 'Saldo a receber',
                    valor: reais(r.contratadoEmAberto),
                    detalhe: '${plural(r.fretesEmAberto, 'frete', 'fretes')} esperando o saldo',
                    corValor: cores.atencao,
                  ),
              ],
            ),
          ),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: TituloSecao('Quem dirigiu')),
          if (usos.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Nota('Ninguém usou ainda.')),
          for (final u in usos)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: Icon(u.aberto ? Icons.person : Icons.person_outline),
              title: Text(e.nomeMotorista(u.motoristaId)),
              subtitle: Text(
                'De ${dataTexto(u.inicioEm.toLocal())} '
                '${u.fimEm == null ? 'até agora' : 'a ${dataTexto(u.fimEm!.toLocal())}'}',
              ),
            ),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: TituloSecao('Fretes do período')),
          ListaPorMes<Frete>(
            itens: d.fretes,
            data: (f) => f.dataCarga,
            valor: (f) => f.freteRealCentavos,
            item: (f) => ItemFrete(frete: f, equipe: e),
            vazio: 'Nenhum frete neste caminhão no período.',
          ),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: TituloSecao('Abastecidas do período')),
          ListaPorMes<Abastecimento>(
            itens: e.abastecimentos.where((a) => a.caminhaoId == c.id && periodo.contem(a.data)).toList(),
            data: (a) => a.data,
            valor: (a) => a.valorCentavos,
            item: (a) => ItemAbastecimento(abastecimento: a, equipe: e),
            vazio: 'Nenhuma abastecida neste caminhão no período.',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: OutlinedButton.icon(
              onPressed: ativar,
              icon: Icon(c.ativo ? Icons.pause_circle_outline : Icons.play_circle_outline),
              label: Text(c.ativo ? 'Parar este caminhão' : 'Voltar este caminhão'),
            ),
          ),
        ],
      ),
    );
  }
}
