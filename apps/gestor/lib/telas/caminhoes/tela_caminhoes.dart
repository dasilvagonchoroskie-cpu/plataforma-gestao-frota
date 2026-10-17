import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/comuns.dart';
import '../../dados/provedores.dart';
import '../casca.dart';
import 'detalhe_caminhao.dart';

/// Caminhões da empresa, com quem está em cada um e o resultado do período.
class TelaCaminhoes extends ConsumerWidget {
  const TelaCaminhoes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = assistirEquipe(ref);
    final periodo = ref.watch(periodoProvider).periodoOuMes;
    final cores = context.cores;
    final ativos = e.caminhoes.where((c) => c.ativo).toList()
      ..sort((a, b) => a.confirmado == b.confirmado ? a.placa.compareTo(b.placa) : (a.confirmado ? 1 : -1));
    final inativos = e.caminhoes.where((c) => !c.ativo).toList();

    Widget linha(Caminhao c) {
      final d = e.relatorio(periodo, caminhaoId: c.id);
      final quem = e.motoristasNoCaminhao(c.id);
      final km = e.kmRodados(c.id, periodo);
      final media = mediaDoPeriodo(d.abastecimentos, e.abastecimentos).media;
      return InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TelaDetalheCaminhao(caminhaoId: c.id))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              PlacaVeiculo(c.placa, tamanho: 17),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          [
                            if (c.numeroFrota != null) 'Frota ${c.numeroFrota}',
                            if (c.modelo.isNotEmpty) c.modelo,
                          ].join('  ·  ').ifEmpty('Sem modelo'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        if (!c.confirmado) const Etiqueta('Para conferir'),
                        if (!c.ativo) const Etiqueta('Parado', atencao: false),
                        if (quem.length > 1) Etiqueta('${quem.length} motoristas'),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        quem.isEmpty ? 'Sem motorista agora' : quem.map((m) => m.primeiroNome).join(', '),
                        if (km > 0) '${semCasas(km)} km',
                        if (media != null) '${umaCasa(media)} km/L',
                      ].join('  ·  '),
                      style: TextStyle(fontSize: 14, color: cores.textoFraco),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    reais(d.resultado.sobraDoCaminhao),
                    style: estiloNumero(17, cor: d.resultado.sobraDoCaminhao < 0 ? cores.negativo : null),
                  ),
                  Text('resultado', style: TextStyle(fontSize: 12.5, color: cores.textoFraco)),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Caminhões'), actions: acoesPadrao(context, ref)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'novo_caminhao',
        onPressed: () => abrirFormCaminhao(context),
        icon: const Icon(Icons.add),
        label: const Text('Novo caminhão'),
      ),
      body: ListaCentral(
        largura: 900,
        children: [
          const SizedBox(height: 4),
          const FaixaPeriodo(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Nota(
              '${e.caminhoesNoPlano} de ${e.empresa.limiteCaminhoes} caminhões do plano em uso. '
              'Caminhão cadastrado pelo motorista entra como "para conferir" até você confirmar.',
            ),
          ),
          if (e.caminhoes.isEmpty)
            EstadoVazio(
              icone: Icons.local_shipping_outlined,
              titulo: 'Nenhum caminhão cadastrado',
              texto: 'Cadastre os caminhões da frota. O motorista escolhe em qual está no app dele.',
              acao: FilledButton.icon(
                onPressed: () => abrirFormCaminhao(context),
                icon: const Icon(Icons.add),
                label: const Text('Cadastrar o primeiro'),
              ),
            ),
          for (var i = 0; i < ativos.length; i++) ...[
            if (i > 0) const Divider(indent: 20, endIndent: 20, height: 1),
            linha(ativos[i]),
          ],
          if (inativos.isNotEmpty) ...[
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: TituloSecao('Parados')),
            for (final c in inativos) linha(c),
          ],
        ],
      ),
    );
  }
}

extension on String {
  String ifEmpty(String outro) => isEmpty ? outro : this;
}

/// Cadastro ou edição de um caminhão.
Future<void> abrirFormCaminhao(BuildContext context, {Caminhao? caminhao}) => showDialog<void>(
  context: context,
  builder: (_) => FormCaminhao(caminhao: caminhao),
);

class FormCaminhao extends ConsumerStatefulWidget {
  const FormCaminhao({super.key, this.caminhao});
  final Caminhao? caminhao;

  @override
  ConsumerState<FormCaminhao> createState() => _FormCaminhaoState();
}

class _FormCaminhaoState extends ConsumerState<FormCaminhao> {
  late final _placa = TextEditingController(text: widget.caminhao?.placa ?? '');
  late final _frota = TextEditingController(text: widget.caminhao?.numeroFrota ?? '');
  late final _modelo = TextEditingController(text: widget.caminhao?.modelo ?? '');
  late final _ano = TextEditingController(text: widget.caminhao?.ano?.toString() ?? '');
  String? _erro;

  Future<void> _salvar() async {
    final placa = normalizarPlaca(_placa.text);
    if (!placaValida(placa)) return setState(() => _erro = 'Placa inválida. Use o formato ABC1D23 ou ABC1234.');
    final e = ref.read(equipeProvider).requireValue;
    if (e.caminhoes.any((c) => c.placa == placa && c.id != widget.caminhao?.id)) {
      return setState(() => _erro = 'Já existe um caminhão com a placa ${placaTexto(placa)}.');
    }
    final ano = int.tryParse(_ano.text.trim());
    if (_ano.text.trim().isNotEmpty && (ano == null || ano < 1950 || ano > 2100)) {
      return setState(() => _erro = 'Ano inválido.');
    }
    final navegador = Navigator.of(context);
    final ok = await executar(
      context,
      () => ref
          .read(equipeProvider.notifier)
          .salvarCaminhao(
            id: widget.caminhao?.id,
            placa: placa,
            numeroFrota: _frota.text,
            modelo: _modelo.text,
            ano: ano,
          ),
      sucesso: widget.caminhao == null ? 'Caminhão cadastrado.' : 'Caminhão salvo.',
    );
    if (ok) navegador.pop();
  }

  @override
  Widget build(BuildContext context) {
    final novo = widget.caminhao == null;
    return AlertDialog(
      title: Text(novo ? 'Novo caminhão' : 'Caminhão ${placaTexto(widget.caminhao!.placa)}'),
      scrollable: true,
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Campo(controle: _placa, rotulo: 'Placa', tipo: TipoCampo.placa, autofoco: novo),
            const SizedBox(height: 12),
            Campo(controle: _frota, rotulo: 'Número da frota (opcional)', dica: 'Ex.: 07'),
            const SizedBox(height: 12),
            Campo(
              controle: _modelo,
              rotulo: 'Modelo (opcional)',
              dica: 'Ex.: Scania R450',
              maiusculas: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            Campo(controle: _ano, rotulo: 'Ano (opcional)', tipo: TipoCampo.numeros),
            if (!novo && !widget.caminhao!.confirmado) ...[
              const SizedBox(height: 12),
              const Nota('Ao salvar, o caminhão fica confirmado e entra na conta do plano.'),
            ],
            if (_erro != null) ...[
              const SizedBox(height: 10),
              Text(_erro!, style: TextStyle(color: context.cores.negativo, fontSize: 14.5)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _salvar, child: const Text('Salvar')),
      ],
    );
  }
}
