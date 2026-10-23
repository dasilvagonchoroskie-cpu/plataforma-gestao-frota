import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/comuns.dart';
import '../../dados/provedores.dart';

/// Registro de paradas: o dono liga ou desliga e define o limite sem
/// descanso da empresa. Nenhum número fica no app: o padrão vem do banco.
class TelaConfigParadas extends ConsumerStatefulWidget {
  const TelaConfigParadas({super.key});

  @override
  ConsumerState<TelaConfigParadas> createState() => _TelaConfigParadasState();
}

class _TelaConfigParadasState extends ConsumerState<TelaConfigParadas> {
  late final _empresa = ref.read(equipeProvider).requireValue.empresa;
  late bool _ativas = _empresa.paradasAtivas;
  late final _horas = TextEditingController(text: _empresa.limiteSemDescansoMinutos == null
      ? ''
      : '${_empresa.limiteSemDescansoMinutos! ~/ 60}');
  late final _minutos = TextEditingController(text: _empresa.limiteSemDescansoMinutos == null
      ? ''
      : '${_empresa.limiteSemDescansoMinutos! % 60}');
  String? _erro;

  @override
  void dispose() {
    _horas.dispose();
    _minutos.dispose();
    super.dispose();
  }

  int get _limite => lerNumero(_horas.text).round() * 60 + lerNumero(_minutos.text).round();

  Future<void> _salvar() async {
    final limite = _limite;
    final minutos = lerNumero(_minutos.text).round();
    // A faixa aceita é a do banco (meia hora a um dia); não é número da lei.
    if (minutos > 59) return setState(() => _erro = 'Os minutos vão de 0 a 59.');
    if (limite < 30 || limite > 24 * 60) {
      return setState(() => _erro = 'O limite fica entre 0h30 e 24h00.');
    }
    final navegador = Navigator.of(context);
    final ok = await executar(
      context,
      () => ref.read(equipeProvider.notifier).salvarParadas(ativas: _ativas, limiteMinutos: limite),
      sucesso: _ativas
          ? 'Registro de paradas ligado. Os apps dos motoristas mostram a aba na próxima conexão.'
          : 'Registro de paradas desligado. As paradas já registradas continuam guardadas.',
    );
    if (ok) navegador.pop();
  }

  @override
  Widget build(BuildContext context) {
    final e = assistirEquipe(ref);
    final cores = context.cores;
    final dono = e.souDono;
    Widget pergunta(String texto) => Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 8),
      child: Text(texto, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600)),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Registro de paradas')),
      bottomNavigationBar: dono ? RodapeBotao(texto: 'Salvar', aoTocar: _salvar) : null,
      body: ListaCentral(
        largura: 620,
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 120),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'O motorista toca em "Registrar parada", escolhe o motivo e, na saída, em "Retomar viagem". '
                  'O painel mostra as paradas de cada um e o maior intervalo sem descanso. Funciona sem internet.',
                  style: TextStyle(fontSize: 15.5, color: cores.textoFraco),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _ativas,
                  onChanged: dono ? (v) => setState(() => _ativas = v) : null,
                  title: const Text('Usar o registro de paradas', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Desligado, a aba não aparece para os motoristas nem no painel.'),
                ),
                pergunta('Limite sem descanso da empresa'),
                Row(
                  children: [
                    Expanded(
                      child: Campo(controle: _horas, rotulo: 'Horas', tipo: TipoCampo.inteiro, aoMudar: (_) => setState(() => _erro = null)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Campo(controle: _minutos, rotulo: 'Minutos', tipo: TipoCampo.inteiro, aoMudar: (_) => setState(() => _erro = null)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Nota(
                  'Intervalo sem descanso maior que ${_limite >= 30 ? limiteTexto(_limite) : 'isto'} fica em vermelho no painel e no '
                  'relatório. A empresa define o número; o app não guarda número de lei nenhum.',
                ),
                if (_erro != null) ...[
                  const SizedBox(height: 10),
                  Text(_erro!, style: TextStyle(color: cores.negativo)),
                ],
                pergunta('Motivos'),
                for (final m in e.motivosParada.where((m) => m.ativo))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(iconeDoMotivo(m.codigo)),
                    title: Text(m.nome, style: const TextStyle(fontSize: 15.5)),
                    trailing: m.contaComoDescanso ? const Etiqueta('Conta como descanso', atencao: false) : null,
                  ),
                const SizedBox(height: 8),
                const Nota(avisoParadas),
                if (!dono) ...[
                  const SizedBox(height: 12),
                  const Nota('Só o dono liga, desliga e muda o limite.'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
