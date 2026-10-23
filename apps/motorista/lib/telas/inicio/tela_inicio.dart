import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/comuns.dart';
import '../acertos/tela_acertos.dart';
import '../acesso/telas_acesso.dart';
import '../configuracoes/tela_configuracoes.dart';
import '../diesel/tela_diesel.dart';
import '../fretes/tela_fretes.dart';
import '../gastos/tela_gastos.dart';
import '../paradas/tela_paradas.dart';
import '../relatorio/tela_relatorio.dart';
import '../vales/tela_vales.dart';
import '../viagens/tela_viagens.dart';
import 'lancar.dart';

/// Início (o do cartaz): o caminhão, o que está acontecendo agora e os botões
/// grandes de cada parte, cada um com uma linha do mês.
class TelaInicio extends ConsumerWidget {
  const TelaInicio({super.key, this.irParaResumo});

  /// O botão Resumo leva para a aba Resumo.
  final VoidCallback? irParaResumo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dados = assistirDados(ref);
    final cores = context.cores;
    final mes = calcularPeriodo(TipoPeriodo.mesAtual)!;
    final d = dados.dadosDoPeriodo(mes);
    final r = d.resultado;
    final media = mediaDoPeriodo(d.abastecimentos, dados.abastecimentos).media;
    final aberta = dados.viagemEmAndamento;
    final parada = dados.paradaEmAndamento;
    final nomeMes = mesAno(mes.inicio).split(' ').first;
    void abrir(Widget tela) => Navigator.push(context, MaterialPageRoute(builder: (_) => tela));

    final itens = <Widget>[
      if (dados.porViagem)
        ItemMenu(
          icone: Icons.route_outlined,
          categoria: Categoria.viagens,
          titulo: 'Viagens',
          subtitulo: aberta != null
              ? 'Carreta ${placaTexto(aberta.placaCarreta)} engatada'
              : '${plural(d.viagens.length, 'viagem', 'viagens')} em $nomeMes',
          destaque: aberta != null ? 'em andamento' : null,
          aoTocar: () => abrir(const TelaViagens()),
        )
      else
        ItemMenu(
          icone: Icons.local_shipping_outlined,
          categoria: Categoria.fretes,
          titulo: 'Fretes',
          subtitulo: r.quantidadeFretes == 0
              ? 'Nenhum frete em $nomeMes'
              : '${plural(r.quantidadeFretes, 'frete', 'fretes')} em $nomeMes · ${reais(r.totalFretes)}',
          aoTocar: () => abrir(const TelaFretes()),
        ),
      ItemMenu(
        icone: Icons.local_gas_station_outlined,
        categoria: Categoria.diesel,
        titulo: 'Diesel',
        subtitulo: d.abastecimentos.isEmpty
            ? 'Nenhuma abastecida em $nomeMes'
            : '${reais(r.totalAbastecimento)}${media == null ? '' : ' · média ${umaCasa(media)} km/L'}',
        aoTocar: () => abrir(const TelaDiesel()),
      ),
      ItemMenu(
        icone: Icons.receipt_long_outlined,
        categoria: Categoria.gastos,
        titulo: 'Gastos',
        subtitulo: d.gastos.isEmpty
            ? 'Borracharia, chapa, lavagem...'
            : '${plural(d.gastos.length, 'gasto', 'gastos')} em $nomeMes · ${reais(r.totalGastos)}',
        aoTocar: () => abrir(const TelaGastos()),
      ),
      ItemMenu(
        icone: Icons.payments_outlined,
        categoria: Categoria.vales,
        titulo: 'Vales',
        subtitulo: d.vales.isEmpty ? 'Dinheiro pego adiantado' : '${reais(r.totalVale)} em $nomeMes',
        aoTocar: () => abrir(const TelaVales()),
      ),
      if (dados.paradasAtivas)
        ItemMenu(
          icone: Icons.pause_circle_outline,
          categoria: Categoria.paradas,
          titulo: 'Paradas',
          subtitulo: parada != null
              ? '${nomeDoMotivo(parada.motivo, dados.info.paradas.motivos)} desde as ${horaTexto(parada.inicioEm)}'
              : 'Registrar parada e retomar viagem',
          destaque: parada != null ? 'parado' : null,
          aoTocar: () => abrir(const TelaParadas()),
        ),
      if (dados.porViagem)
        ItemMenu(
          icone: Icons.handshake_outlined,
          categoria: Categoria.comissao,
          titulo: 'Acertos',
          subtitulo: dados.acertos.isEmpty
              ? 'Os acertos fechados pelo patrão'
              : 'Último: ${reais(dados.acertos.first.paraReceberCentavos)} (${dados.acertos.first.periodoTexto})',
          aoTocar: () => abrir(const TelaAcertos()),
        ),
      ItemMenu(
        icone: Icons.insights_outlined,
        categoria: Categoria.resumo,
        titulo: 'Resumo',
        subtitulo: dados.porViagem
            ? 'O mês, as viagens e o relatório em PDF'
            : 'Para receber em $nomeMes: ${reais(r.liquido)}',
        aoTocar: irParaResumo,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 16,
        title: Row(
          children: [
            const MarcaApp(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Frota Motorista', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  Text(
                    [
                      if (dados.info.nome.isNotEmpty) 'Olá, ${dados.info.nome.split(' ').first}',
                      if (dados.info.empresaNome.isNotEmpty) dados.info.empresaNome,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: cores.textoFraco),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Relatório em PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => abrir(const TelaRelatorio()),
          ),
          IconButton(
            tooltip: 'Configurações',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => abrir(const TelaConfiguracoes()),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'lancar_inicio',
        onPressed: () => abrirLancar(context, ref),
        icon: const Icon(Icons.add, size: 28),
        label: const Text('Lançar', style: TextStyle(fontSize: 19)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 110),
        children: [
          const TopoCaminhao(),
          const LinhaEnvio(),
          const AvisoConfirmarEmail(),
          if (dados.info.suspensa)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Aviso(
                icone: Icons.pause_circle_outline,
                titulo: 'Empresa suspensa',
                texto: 'Os seus lançamentos ficam guardados no celular e vão ser enviados quando a empresa voltar.',
              ),
            ),
          // O que está acontecendo agora fica em cima, com os botões à mão.
          if (dados.paradasAtivas && parada != null)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: CartaoSituacaoParada(soQuandoParado: true),
            ),
          if (dados.porViagem && aberta != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: CartaoViagemAberta(viagem: aberta),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Text('O que você quer ver?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          for (var i = 0; i < itens.length; i++)
            Padding(padding: EdgeInsets.fromLTRB(16, i == 0 ? 0 : 10, 16, 0), child: itens[i]),
        ],
      ),
    );
  }
}
