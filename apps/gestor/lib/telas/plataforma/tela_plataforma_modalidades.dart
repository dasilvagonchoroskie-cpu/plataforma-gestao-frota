import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/comuns.dart';
import '../../dados/provedores.dart';
import '../../servidor/servidor.dart';

/// Catálogo de modalidades da plataforma (todas, ligadas ou não).
final modalidadesPlataformaProvider = FutureProvider.autoDispose<List<Modalidade>>((ref) async {
  final lista = await ref.read(servidorProvider).plataformaModalidades();
  return [for (final m in lista) Modalidade.deMapa(m)];
});

/// Super administrador: cria modalidades novas e campos novos. As empresas
/// recebem sem atualizar o app (o dono liga e ajusta em Configurações).
class TelaPlataformaModalidades extends ConsumerWidget {
  const TelaPlataformaModalidades({super.key});

  Future<void> _nova(BuildContext context, WidgetRef ref) async {
    final r = await showDialog<(String, TipoModalidade)>(context: context, builder: (_) => const _DialogoModalidade());
    if (r == null || !context.mounted) return;
    final ok = await executar(
      context,
      () => ref
          .read(servidorProvider)
          .plataformaSalvarModalidade(codigo: codigoDoNome(r.$1), nome: r.$1, tipo: r.$2.name),
      sucesso: 'Modalidade criada. Os donos já podem ligar em Configurações.',
    );
    if (ok) ref.invalidate(modalidadesPlataformaProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lista = ref.watch(modalidadesPlataformaProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modalidades e campos'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(modalidadesPlataformaProvider),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'nova_modalidade',
        onPressed: () => _nova(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nova modalidade'),
      ),
      body: lista.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Aviso(texto: traduzirErro(e).mensagem, icone: Icons.error_outline),
          ),
        ),
        data: (l) => ListaCentral(
          largura: 760,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Nota(
                'Aqui ficam as modalidades que as empresas podem ligar. Campo novo criado aqui aparece no app '
                'do motorista sem precisar de versão nova. O dono de cada empresa pode renomear, esconder ou '
                'tornar obrigatório.',
              ),
            ),
            for (final m in l)
              ListTile(
                contentPadding: const EdgeInsets.fromLTRB(20, 4, 16, 4),
                leading: Icon(m.porViagem ? Icons.route_outlined : Icons.local_shipping_outlined),
                title: Text(m.nome, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '${m.porViagem ? 'Por viagem' : 'Por frete'}  ·  '
                  '${plural(m.campos.where((c) => c.extra && !c.desativado).length, 'campo novo', 'campos novos')}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TelaPlataformaCampos(codigo: m.codigo)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DialogoModalidade extends StatefulWidget {
  const _DialogoModalidade();

  @override
  State<_DialogoModalidade> createState() => _DialogoModalidadeState();
}

class _DialogoModalidadeState extends State<_DialogoModalidade> {
  final _nome = TextEditingController();
  var _tipo = TipoModalidade.frete;
  String? _erro;

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nova modalidade'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Campo(
              controle: _nome,
              rotulo: 'Nome',
              dica: 'Porta-contêiner',
              erro: _erro,
              autofoco: true,
              maiusculas: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
            const Text('Como funciona', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            OpcaoEscolha<TipoModalidade>(
              valor: TipoModalidade.frete,
              escolhido: _tipo,
              titulo: 'Por frete (como o Graneleiro)',
              descricao: 'Carga, peso, adiantamento, saldo e comissão em cada frete.',
              aoEscolher: (v) => setState(() => _tipo = v),
            ),
            OpcaoEscolha<TipoModalidade>(
              valor: TipoModalidade.viagem,
              escolhido: _tipo,
              titulo: 'Por viagem (como o Baú)',
              descricao: 'Carreta engatada, até onde levou e entregas. A comissão sai no acerto.',
              aoEscolher: (v) => setState(() => _tipo = v),
            ),
            const Nota('O jeito de funcionar não muda depois.'),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(
        onPressed: () {
          final n = _nome.text.trim();
          if (n.length < 2 || n.length > 40) {
            setState(() => _erro = 'Escreva o nome (até 40 letras).');
            return;
          }
          Navigator.pop(context, (n, _tipo));
        },
        child: const Text('Criar'),
      ),
    ],
  );
}

/// Campos de uma modalidade do catálogo: os de fábrica (só leitura) e os novos.
class TelaPlataformaCampos extends ConsumerWidget {
  const TelaPlataformaCampos({super.key, required this.codigo});
  final String codigo;

  Future<void> _campo(BuildContext context, WidgetRef ref, Modalidade m, {CampoModalidade? atual}) async {
    final r = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => _DialogoCampo(modalidade: m, atual: atual),
    );
    if (r == null || !context.mounted) return;
    final ok = await executar(
      context,
      () => ref.read(servidorProvider).plataformaSalvarCampo(m.codigo, r),
      sucesso: atual == null ? 'Campo criado.' : 'Campo salvo.',
    );
    if (ok) ref.invalidate(modalidadesPlataformaProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lista = ref.watch(modalidadesPlataformaProvider);
    final cores = context.cores;
    final m = lista.value == null ? null : modalidadePorCodigo(lista.value!, codigo);
    if (m == null) {
      return Scaffold(
        appBar: AppBar(),
        body: lista.isLoading ? const Center(child: CircularProgressIndicator()) : const SizedBox.shrink(),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('Campos: ${m.nome}')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'novo_campo',
        onPressed: () => _campo(context, ref, m),
        icon: const Icon(Icons.add),
        label: const Text('Novo campo'),
      ),
      body: ListaCentral(
        largura: 760,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Nota(
              m.porViagem
                  ? 'Por viagem. Os campos de fábrica não mudam aqui. Toque num campo novo para mudar ou desativar.'
                  : 'Por frete. Os campos de fábrica não mudam aqui. Toque num campo novo para mudar ou desativar.',
            ),
          ),
          for (final c in m.campos)
            ListTile(
              contentPadding: const EdgeInsets.fromLTRB(20, 2, 16, 2),
              leading: Icon(c.extra ? Icons.add_box_outlined : Icons.lock_outline, color: cores.textoFraco),
              title: Text(
                c.rotulo,
                style: TextStyle(decoration: c.desativado ? TextDecoration.lineThrough : null),
              ),
              subtitle: Text(
                [
                  TiposCampo.nome(c.tipo),
                  if (c.etapa != null) EtapasViagem.nome(c.etapa!).split(' (').first,
                  if (c.obrigatorio) 'obrigatório',
                  if (c.desativado) 'desativado',
                  if (!c.extra) 'de fábrica',
                ].join('  ·  '),
              ),
              onTap: c.extra ? () => _campo(context, ref, m, atual: c) : null,
            ),
        ],
      ),
    );
  }
}

class _DialogoCampo extends StatefulWidget {
  const _DialogoCampo({required this.modalidade, this.atual});
  final Modalidade modalidade;
  final CampoModalidade? atual;

  @override
  State<_DialogoCampo> createState() => _DialogoCampoState();
}

class _DialogoCampoState extends State<_DialogoCampo> {
  late final _rotulo = TextEditingController(text: widget.atual?.rotulo ?? '');
  late String _tipo = widget.atual?.tipo ?? TiposCampo.texto;
  late String _etapa = widget.atual?.etapa ?? EtapasViagem.engate;
  late bool _obrigatorio = widget.atual?.obrigatorio ?? false;
  late bool _desativado = widget.atual?.desativado ?? false;
  String? _erro;

  bool get _novo => widget.atual == null;

  @override
  void dispose() {
    _rotulo.dispose();
    super.dispose();
  }

  void _salvar() {
    final r = _rotulo.text.trim();
    if (r.length < 2 || r.length > 40) {
      setState(() => _erro = 'Escreva o nome do campo (até 40 letras).');
      return;
    }
    Navigator.pop(context, <String, Object?>{
      'chave': widget.atual?.chave ?? codigoDoNome(r),
      'rotulo': r,
      'tipo': _tipo,
      'obrigatorio': _obrigatorio,
      'desativado': _desativado,
      if (widget.modalidade.porViagem) 'etapa': _etapa,
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(_novo ? 'Novo campo em ${widget.modalidade.nome}' : 'Campo'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Campo(controle: _rotulo, rotulo: 'Nome que o motorista vê', dica: 'Número do lacre', erro: _erro),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _tipo,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: [
                for (final t in TiposCampo.paraCampoNovo) DropdownMenuItem(value: t, child: Text(TiposCampo.nome(t))),
              ],
              onChanged: _novo ? (v) => setState(() => _tipo = v ?? _tipo) : null,
            ),
            if (!_novo) const Nota('O tipo não muda depois de criado.'),
            if (widget.modalidade.porViagem) ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _etapa,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Quando o motorista preenche'),
                items: [
                  for (final e in EtapasViagem.todas) DropdownMenuItem(value: e, child: Text(EtapasViagem.nome(e))),
                ],
                onChanged: (v) => setState(() => _etapa = v ?? _etapa),
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Obrigatório'),
              value: _obrigatorio,
              onChanged: (v) => setState(() => _obrigatorio = v),
            ),
            if (!_novo)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Desativado'),
                subtitle: const Text('Some dos formulários. O que já foi anotado fica guardado.'),
                value: _desativado,
                onChanged: (v) => setState(() => _desativado = v),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(onPressed: _salvar, child: Text(_novo ? 'Criar' : 'Salvar')),
    ],
  );
}
