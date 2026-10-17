import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/comuns.dart';
import '../../dados/dados.dart';
import '../../dados/rascunho.dart';

class TelaVales extends ConsumerWidget {
  const TelaVales({super.key});

  void _novo(BuildContext context) => Navigator.push(context, MaterialPageRoute(builder: (_) => const FormVale()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dados = assistirDados(ref);
    final grupos = agruparPorMes<Vale>(dados.vales, (v) => v.data);

    return Scaffold(
      appBar: AppBar(title: const Text('Vales')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'novo_vale',
        onPressed: () => _novo(context),
        icon: const Icon(Icons.add),
        label: const Text('Novo vale'),
      ),
      body: dados.vales.isEmpty
          ? ListView(children: [
              EstadoVazio(
                icone: Icons.payments_outlined,
                titulo: 'Nenhum vale anotado',
                texto: 'Anote aqui o dinheiro que você pegou adiantado da empresa. Ele desconta do que você tem para receber.',
                acao: FilledButton.icon(
                  onPressed: () => _novo(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Anotar vale'),
                ),
              ),
            ])
          : ListView(
              children: [
                for (final g in grupos) ...[
                  CabecalhoMes(titulo: g.titulo, resumo: reais(g.itens.fold<double>(0, (s, e) => s + e.valorCentavos))),
                  for (var i = 0; i < g.itens.length; i++) ...[
                    if (i > 0) const Divider(indent: 20, endIndent: 20),
                    InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FormVale(editando: g.itens[i]))),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
                        child: Row(
                          children: [
                            ColunaData(g.itens[i].data),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text((g.itens[i].observacao ?? '').isEmpty ? 'Vale' : g.itens[i].observacao!,
                                      maxLines: 2, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  MarcasLancamento(
                                    pendente: dados.estaPendente(Tabelas.vales, g.itens[i].id),
                                    ajustado: g.itens[i].ajustado,
                                  ),
                                ],
                              ),
                            ),
                            Text(reais(g.itens[i].valorCentavos), style: estiloNumero(18)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
                espacoFinalLista,
              ],
            ),
    );
  }
}

class FormVale extends ConsumerStatefulWidget {
  const FormVale({super.key, this.editando});
  final Vale? editando;

  @override
  ConsumerState<FormVale> createState() => _FormValeState();
}

class _FormValeState extends ConsumerState<FormVale> {
  final _valor = TextEditingController();
  final _observacao = TextEditingController();
  late DateTime _data;
  String? _erroValor;
  Rascunho? _rascunho;

  bool get _novo => widget.editando == null;

  @override
  void initState() {
    super.initState();
    _data = inicioDoDia(DateTime.now());
    final v = widget.editando;
    if (v != null) {
      _data = v.data;
      _valor.text = textoDinheiro(v.valorCentavos);
      _observacao.text = v.observacao ?? '';
    } else {
      final r = Rascunho(ref.read(armazenamentoProvider), 'vale');
      _rascunho = r;
      r.ler().then((m) {
        if (m.isEmpty || !mounted) return;
        setState(() {
          _valor.text = (m['valor'] as String?) ?? '';
          _observacao.text = (m['observacao'] as String?) ?? '';
          final d = DateTime.tryParse((m['data'] as String?) ?? '');
          if (d != null) _data = d;
        });
      });
    }
  }

  @override
  void dispose() {
    _valor.dispose();
    _observacao.dispose();
    super.dispose();
  }

  void _mudou([String? _]) {
    setState(() => _erroValor = null);
    if (_novo) _rascunho?.gravar({'valor': _valor.text, 'observacao': _observacao.text, 'data': _data.toIso8601String()});
  }

  Future<void> _salvar() async {
    final valor = lerCentavos(_valor.text);
    setState(() => _erroValor = valor <= 0 ? 'Falta o valor do vale.' : null);
    if (_erroValor != null) return;
    final d = ref.read(dadosProvider).requireValue;
    final vale = widget.editando?.copyWith(data: _data, valorCentavos: valor, observacao: _observacao.text.trim()) ??
        Vale(
          id: novoId(),
          motoristaId: d.info.motoristaId ?? '',
          data: _data,
          valorCentavos: valor,
          observacao: _observacao.text.trim().isEmpty ? null : _observacao.text.trim(),
          criadoNoAparelhoEm: DateTime.now(),
        );
    await ref.read(dadosProvider.notifier).salvarVale(vale);
    await _rascunho?.limpar();
    if (!mounted) return;
    final mensageiro = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    mensageiro.showSnackBar(SnackBar(content: Text(_novo ? 'Vale salvo.' : 'Alteração salva.')));
  }

  Future<void> _apagar() async {
    final v = widget.editando!;
    final ok = await confirmarExclusao(
      context,
      titulo: 'Apagar este vale?',
      detalhe: '${dataTexto(v.data)}, ${reais(v.valorCentavos)}. O seu patrão vai ver que foi apagado.',
    );
    if (!ok || !mounted) return;
    final mensageiro = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    await ref.read(dadosProvider.notifier).apagarVale(v);
    mensageiro.showSnackBar(const SnackBar(content: Text('Vale apagado.')));
  }

  @override
  Widget build(BuildContext context) {
    final dados = assistirDados(ref);
    final ajustes = _novo ? const <AjusteGestor>[] : dados.ajustesDe(widget.editando!.id);
    final bloqueado = ajustes.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(_novo ? 'Novo vale' : 'Mudar vale'),
        actions: [
          if (!_novo && !bloqueado) IconButton(tooltip: 'Apagar', icon: const Icon(Icons.delete_outline), onPressed: _apagar),
        ],
      ),
      bottomNavigationBar: bloqueado ? null : RodapeBotao(texto: _novo ? 'Salvar vale' : 'Salvar alteração', aoTocar: _salvar),
      body: AbsorbPointer(
        absorbing: bloqueado,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            AvisoAjustado(ajustes: ajustes),
            CampoData(
              rotulo: 'Data',
              valor: _data,
              aoMudar: (v) {
                _data = v;
                _mudou();
              },
            ),
            const SizedBox(height: 14),
            Campo(controle: _valor, rotulo: 'Valor', tipo: TipoCampo.dinheiro, erro: _erroValor, aoMudar: _mudou, autofoco: _novo),
            const SizedBox(height: 14),
            Campo(controle: _observacao, rotulo: 'Observação', ajuda: 'Opcional. Ex.: vale do posto, adiantamento.', aoMudar: _mudou),
          ],
        ),
      ),
    );
  }
}
