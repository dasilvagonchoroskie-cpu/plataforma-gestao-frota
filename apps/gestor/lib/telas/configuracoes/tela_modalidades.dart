import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/comuns.dart';
import '../../dados/provedores.dart';

String descricaoDoTipo(Modalidade m) => m.porViagem
    ? 'Por viagem: o motorista anota a carreta, até onde levou e as entregas. A comissão sai no acerto.'
    : 'Por frete: carga, peso, adiantamento, saldo e comissão em cada frete.';

/// Modalidades com que a empresa trabalha. O dono liga e desliga e ajusta os
/// campos de cada uma; o gestor só vê.
class TelaModalidades extends ConsumerWidget {
  const TelaModalidades({super.key});

  Future<void> _ligar(BuildContext context, WidgetRef ref, Modalidade m, bool ligar) async {
    if (!ligar) {
      final ok = await confirmar(
        context,
        titulo: 'Desligar ${m.nome}?',
        texto: 'Os motoristas não poderão mais ser colocados nesta modalidade. O que já foi lançado continua guardado.',
        botao: 'Desligar',
        perigo: true,
      );
      if (!ok || !context.mounted) return;
    }
    await executar(
      context,
      () => ref.read(equipeProvider.notifier).salvarModalidade(m.codigo, ligar),
      sucesso: ligar ? '${m.nome} ligada.' : '${m.nome} desligada.',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = assistirEquipe(ref);
    final dono = e.souDono;
    final cores = context.cores;
    return Scaffold(
      appBar: AppBar(title: const Text('Modalidades de operação')),
      body: ListaCentral(
        largura: 760,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Nota(
              dono
                  ? 'Ligue as modalidades com que a empresa trabalha. Cada motorista fica em uma. '
                        'Toque numa modalidade para mudar os nomes dos campos, esconder ou tornar obrigatório.'
                  : 'Só o dono liga as modalidades e muda os campos. Aqui você vê como está.',
            ),
          ),
          for (final m in e.modalidades)
            ListTile(
              contentPadding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
              leading: Icon(m.porViagem ? Icons.route_outlined : Icons.local_shipping_outlined),
              title: Text(m.nome, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${m.porViagem ? 'Por viagem' : 'Por frete'}'
                '${m.ativa ? '  ·  ${plural(m.motoristas, 'motorista', 'motoristas')}' : '  ·  desligada'}',
                style: TextStyle(color: m.ativa ? null : cores.textoFraco),
              ),
              trailing: Switch(
                value: m.ativa,
                onChanged: dono ? (v) => _ligar(context, ref, m, v) : null,
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TelaCamposModalidade(codigo: m.codigo)),
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Nota(
              'Caçamba e Grade baixa funcionam como o Graneleiro. Sider funciona como o Baú. '
              'Campos novos (que não existem em nenhuma) são criados pela Plataforma e aparecem aqui sem atualizar o app.',
            ),
          ),
        ],
      ),
    );
  }
}

/// Campos de uma modalidade: nome, mostrar e obrigatório (o dono muda).
class TelaCamposModalidade extends ConsumerStatefulWidget {
  const TelaCamposModalidade({super.key, required this.codigo});
  final String codigo;

  @override
  ConsumerState<TelaCamposModalidade> createState() => _TelaCamposModalidadeState();
}

class _TelaCamposModalidadeState extends ConsumerState<TelaCamposModalidade> {
  final _rotulos = <String, TextEditingController>{};
  final _visivel = <String, bool>{};
  final _obrigatorio = <String, bool>{};
  Modalidade? _m;

  @override
  void initState() {
    super.initState();
    final m = ref.read(equipeProvider).requireValue.modalidade(widget.codigo);
    _m = m;
    for (final c in m?.campos ?? const <CampoModalidade>[]) {
      final ajuste = m!.ajustes[c.chave] ?? const {};
      _rotulos[c.chave] = TextEditingController(text: lerTexto(ajuste['rotulo']));
      _visivel[c.chave] = lerBool(ajuste['visivel'], true);
      _obrigatorio[c.chave] = ajuste.containsKey('obrigatorio') ? lerBool(ajuste['obrigatorio']) : c.obrigatorio;
    }
  }

  @override
  void dispose() {
    for (final c in _rotulos.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, Object?> _ajustes() {
    final m = _m!;
    return {
      for (final c in m.campos)
        if (!c.desativado)
          c.chave: {
            if (_rotulos[c.chave]!.text.trim().isNotEmpty) 'rotulo': _rotulos[c.chave]!.text.trim(),
            if (c.podeOcultar) 'visivel': _visivel[c.chave],
            if (c.podeOcultar) 'obrigatorio': (_visivel[c.chave] ?? true) && (_obrigatorio[c.chave] ?? false),
          },
    };
  }

  Future<void> _salvar() async {
    final m = _m!;
    for (final c in _rotulos.values) {
      if (c.text.trim().length > 40) {
        mostrarMensagem(context, 'O nome de cada campo pode ter até 40 letras.');
        return;
      }
    }
    final navegador = Navigator.of(context);
    final ok = await executar(
      context,
      () => ref.read(equipeProvider.notifier).salvarModalidade(m.codigo, m.ativa, campos: _ajustes()),
      sucesso: 'Campos salvos. Os apps dos motoristas recebem na próxima conexão.',
    );
    if (ok) navegador.pop();
  }

  @override
  Widget build(BuildContext context) {
    final e = assistirEquipe(ref);
    final m = _m;
    final cores = context.cores;
    final dono = e.souDono;
    if (m == null) return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    final campos = m.campos.where((c) => !c.desativado).toList();

    return Scaffold(
      appBar: AppBar(title: Text('Campos: ${m.nome}')),
      bottomNavigationBar: dono ? RodapeBotao(texto: 'Salvar campos', aoTocar: _salvar) : null,
      body: ListaCentral(
        largura: 760,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Nota(descricaoDoTipo(m)),
                const SizedBox(height: 8),
                Nota(
                  dono
                      ? 'Deixe o nome em branco para usar o de fábrica. Campos marcados com cadeado são usados nas '
                            'contas e não podem sumir (só mudar o nome).'
                      : 'Só o dono muda os campos.',
                ),
              ],
            ),
          ),
          for (final c in campos)
            Card(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: cores.divisor),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.rotuloPadrao ?? c.rotulo,
                            style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (!c.podeOcultar) Icon(Icons.lock_outline, size: 18, color: cores.textoFraco),
                        if (c.extra) const Etiqueta('Campo novo', atencao: false),
                      ],
                    ),
                    Text(
                      [
                        TiposCampo.nome(c.tipo),
                        if (c.etapa != null) EtapasViagem.nome(c.etapa!).split(' (').first,
                      ].join('  ·  '),
                      style: TextStyle(fontSize: 13.5, color: cores.textoFraco),
                    ),
                    const SizedBox(height: 10),
                    AbsorbPointer(
                      absorbing: !dono,
                      child: Campo(
                        controle: _rotulos[c.chave]!,
                        rotulo: 'Nome que o motorista vê',
                        dica: c.rotuloPadrao ?? c.rotulo,
                      ),
                    ),
                    if (c.podeOcultar) ...[
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Mostrar no app'),
                        value: _visivel[c.chave] ?? true,
                        onChanged: dono ? (v) => setState(() => _visivel[c.chave] = v) : null,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Obrigatório'),
                        subtitle: const Text('O motorista só salva com ele preenchido'),
                        value: (_visivel[c.chave] ?? true) && (_obrigatorio[c.chave] ?? false),
                        onChanged: dono && (_visivel[c.chave] ?? true)
                            ? (v) => setState(() => _obrigatorio[c.chave] = v)
                            : null,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
