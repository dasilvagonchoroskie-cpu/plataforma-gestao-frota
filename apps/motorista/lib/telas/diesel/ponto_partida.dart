import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/comuns.dart';
import '../../dados/dados.dart';

/// Km da última abastecida de tanque cheio antes de começar a usar o app,
/// para a média já sair certa. Toda mudança depois de salvo fica registrada.
class TelaPontoPartida extends ConsumerStatefulWidget {
  const TelaPontoPartida({super.key, required this.caminhaoId});
  final String caminhaoId;

  @override
  ConsumerState<TelaPontoPartida> createState() => _TelaPontoPartidaState();
}

class _TelaPontoPartidaState extends ConsumerState<TelaPontoPartida> {
  final _km = TextEditingController();
  final _cidade = TextEditingController();
  final _motivo = TextEditingController();
  late DateTime _data;
  Abastecimento? _atual;
  String? _erroKm;
  String? _erroMotivo;

  @override
  void initState() {
    super.initState();
    _data = inicioDoDia(DateTime.now());
    _atual = ref.read(dadosProvider).requireValue.pontoDePartidaDo(widget.caminhaoId);
    final p = _atual;
    if (p != null) {
      _km.text = textoInteiro(p.km);
      _cidade.text = p.cidade;
      _data = p.data;
    }
  }

  @override
  void dispose() {
    _km.dispose();
    _cidade.dispose();
    _motivo.dispose();
    super.dispose();
  }

  bool get _mudouKm {
    final p = _atual;
    return p != null && lerNumero(_km.text) != p.km;
  }

  Future<void> _salvar() async {
    final km = lerNumero(_km.text);
    setState(() {
      _erroKm = km <= 0 ? 'Falta o km.' : null;
      _erroMotivo = _mudouKm && _motivo.text.trim().isEmpty
          ? 'Escreva o motivo da mudança. É o que protege você no relatório.'
          : null;
    });
    if (_erroKm != null || _erroMotivo != null) return;
    await ref.read(dadosProvider.notifier).salvarPontoDePartida(
          caminhaoId: widget.caminhaoId,
          km: km,
          data: _data,
          cidade: _cidade.text.trim(),
          motivo: _motivo.text,
        );
    if (!mounted) return;
    final mensageiro = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    mensageiro.showSnackBar(const SnackBar(content: Text('Km inicial salvo.')));
  }

  @override
  Widget build(BuildContext context) {
    final dados = assistirDados(ref);
    const espaco = SizedBox(height: 14);
    return Scaffold(
      appBar: AppBar(title: Text('Km inicial ${placaTexto(dados.placaDe(widget.caminhaoId))}')),
      bottomNavigationBar: RodapeBotao(texto: _mudouKm ? 'Salvar mudança' : 'Salvar', aoTocar: _salvar),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Nota(_atual == null
              ? 'Coloque o km da última abastecida de tanque cheio que você tem anotada deste caminhão. '
                  'A partir dele a média começa a contar.'
              : 'Você está mudando um km inicial que já estava salvo. A mudança fica registrada '
                  'e sai no pé do relatório.'),
          const SizedBox(height: 18),
          Campo(
            controle: _km,
            rotulo: 'Km da última abastecida',
            tipo: TipoCampo.inteiro,
            sufixo: 'km',
            erro: _erroKm,
            aoMudar: (_) => setState(() => _erroKm = null),
          ),
          espaco,
          Campo(controle: _cidade, rotulo: 'Cidade', ajuda: 'Se lembrar', maiusculas: TextCapitalization.words),
          espaco,
          CampoData(rotulo: 'Data', valor: _data, aoMudar: (v) => setState(() => _data = v)),
          if (_mudouKm) ...[
            espaco,
            Campo(
              controle: _motivo,
              rotulo: 'Motivo da mudança',
              dica: 'aferição do painel, troca de painel...',
              erro: _erroMotivo,
              aoMudar: (_) => setState(() => _erroMotivo = null),
            ),
            const SizedBox(height: 8),
            Nota('De ${semCasas(_atual!.km)} para ${_km.text.isEmpty ? '—' : _km.text} km'),
          ],
        ],
      ),
    );
  }
}

/// Lista de todas as mudanças do km inicial.
class TelaHistoricoKm extends ConsumerWidget {
  const TelaHistoricoKm({super.key, this.caminhaoId});
  final String? caminhaoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dados = assistirDados(ref);
    final ajustes = dados.ajustesKm.where((a) => caminhaoId == null || a.caminhaoId == caminhaoId).toList();
    final cores = context.cores;
    return Scaffold(
      appBar: AppBar(title: const Text('Mudanças do km inicial')),
      body: ajustes.isEmpty
          ? ListView(children: const [
              EstadoVazio(
                icone: Icons.history,
                titulo: 'Nenhuma mudança',
                texto: 'Toda vez que o km inicial for alterado, fica registrado aqui com data, hora e motivo. '
                    'Esse registro sai no relatório.',
              ),
            ])
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: ajustes.length,
              separatorBuilder: (context, indice) => const Divider(indent: 20, endIndent: 20),
              itemBuilder: (_, i) {
                final a = ajustes[i];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${dataHoraTexto(a.quando)}   ${placaTexto(dados.placaDe(a.caminhaoId))}',
                          style: TextStyle(fontSize: 14, color: cores.textoFraco)),
                      const SizedBox(height: 4),
                      Text('km ${semCasas(a.kmAnterior)}  para  ${semCasas(a.kmNovo)}', style: estiloNumero(19)),
                      const SizedBox(height: 4),
                      Text('Motivo: ${a.motivo}', style: const TextStyle(fontSize: 15.5)),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
