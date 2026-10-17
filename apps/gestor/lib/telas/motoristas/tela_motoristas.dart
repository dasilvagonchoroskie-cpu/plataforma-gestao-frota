import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:share_plus/share_plus.dart';
import 'package:visual/visual.dart';

import '../../componentes/comuns.dart';
import '../../dados/equipe.dart';
import '../../dados/modelos.dart';
import '../../dados/provedores.dart';
import '../casca.dart';
import 'detalhe_motorista.dart';

/// Motoristas: cadastrar (código individual), códigos esperando, pedidos e a lista.
class TelaMotoristas extends ConsumerWidget {
  const TelaMotoristas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = assistirEquipe(ref);
    final agora = ref.read(relogioProvider)();
    final pendentes = e.pedidosPendentes;
    final ativos = e.motoristas.where((m) => m.ativo).toList();
    final desligados = e.motoristas.where((m) => !m.ativo).toList();
    final convites = e.convites.where((c) => c.valeEm(agora)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Motoristas'), actions: acoesPadrao(context, ref)),
      body: ListaCentral(
        largura: 900,
        children: [
          const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 0), child: CartaoCadastrarMotorista()),
          if (convites.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TituloSecao('Códigos esperando o motorista (${convites.length})'),
            ),
            for (final c in convites) _LinhaConvite(convite: c),
          ],
          if (pendentes.isNotEmpty) ...[
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: TituloSecao('Pedidos para entrar')),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Nota(
                'Confira o nome e o CPF antes de aprovar. Quem você aprovar passa a enviar os lançamentos para o painel.',
              ),
            ),
            for (final p in pendentes) _CartaoPedido(pedido: p, agora: agora),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TituloSecao('Na empresa (${ativos.length})'),
          ),
          if (ativos.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Nota('Nenhum motorista ainda. Toque em "Cadastrar motorista" para gerar o código de cada um.'),
            ),
          for (final m in ativos) LinhaMotorista(motorista: m, equipe: e, agora: agora),
          if (desligados.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TituloSecao('Desligados (${desligados.length})'),
            ),
            for (final m in desligados) LinhaMotorista(motorista: m, equipe: e, agora: agora),
          ],
        ],
      ),
    );
  }
}

/// Recado para mandar ao motorista com o código individual dele.
String recadoConvite(Convite c, String empresa) =>
    'Olá, ${c.nome.split(' ').first}! Para entrar na $empresa pelo app Frota Motorista: '
    '1) instale o app; 2) toque em "Criar minha conta" (nome, CPF e senha); '
    '3) quando o app pedir o código de entrada, digite ${c.codigo}. '
    'O código é só seu, funciona com o seu CPF e vale até ${dataTexto(c.expiraEm)}.';

/// Cadastro do motorista: nome e CPF; o painel gera um código só dele.
class CartaoCadastrarMotorista extends ConsumerWidget {
  const CartaoCadastrarMotorista({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cores = context.cores;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cores.divisor)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Novo motorista', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    'Digite o nome e o CPF. O painel gera um código só dele, que vale 7 dias e funciona uma vez, '
                    'só com aquele CPF. Mande pelo WhatsApp junto com o app.',
                    style: TextStyle(fontSize: 14.5, height: 1.35, color: cores.textoFraco),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => cadastrarMotorista(context, ref),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Cadastrar motorista'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formulário (nome e CPF) e depois o código gerado, pronto para mandar.
Future<void> cadastrarMotorista(BuildContext context, WidgetRef ref) async {
  final dados = await showDialog<(String, String)>(context: context, builder: (_) => const _DialogoNovoMotorista());
  if (dados == null || !context.mounted) return;
  Map<String, Object?>? r;
  final ok = await executar(context, () async {
    r = await ref.read(equipeProvider.notifier).gerarConvite(dados.$1, dados.$2);
  });
  if (!ok || r == null || !context.mounted) return;
  final convite = Convite.deMapa(r!);
  await mostrarConvite(context, convite, ref.read(equipeProvider).requireValue.empresa.nome);
}

Future<void> mostrarConvite(BuildContext context, Convite c, String empresa) {
  final recado = recadoConvite(c, empresa);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Código de ${c.nome.split(' ').first}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: SelectableText(c.codigo, style: estiloNumero(40, peso: FontWeight.w700).copyWith(letterSpacing: 8)),
          ),
          const SizedBox(height: 8),
          Text(
            'CPF ${cpfTexto(c.cpf)}. Vale até ${dataTexto(c.expiraEm)}, uma vez só. '
            'Quando ele digitar o código no app, já entra na empresa.',
            style: const TextStyle(fontSize: 15, height: 1.35),
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: recado));
            if (ctx.mounted) mostrarMensagem(ctx, 'Recado copiado. Cole no WhatsApp do motorista.');
          },
          icon: const Icon(Icons.copy),
          label: const Text('Copiar recado'),
        ),
        TextButton.icon(
          onPressed: () => SharePlus.instance.share(ShareParams(text: recado)),
          icon: const Icon(Icons.share_outlined),
          label: const Text('Enviar'),
        ),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Pronto')),
      ],
    ),
  );
}

class _DialogoNovoMotorista extends StatefulWidget {
  const _DialogoNovoMotorista();

  @override
  State<_DialogoNovoMotorista> createState() => _DialogoNovoMotoristaState();
}

class _DialogoNovoMotoristaState extends State<_DialogoNovoMotorista> {
  final _nome = TextEditingController();
  final _cpf = TextEditingController();
  String? _erroNome;
  String? _erroCpf;

  @override
  void dispose() {
    _nome.dispose();
    _cpf.dispose();
    super.dispose();
  }

  void _gerar() {
    setState(() {
      _erroNome = _nome.text.trim().length < 2 ? 'Escreva o nome do motorista.' : null;
      _erroCpf = cpfValido(_cpf.text) ? null : 'Confira o CPF: tem 11 números.';
    });
    if (_erroNome == null && _erroCpf == null) Navigator.pop(context, (_nome.text.trim(), soDigitos(_cpf.text)));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Cadastrar motorista'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Campo(
            controle: _nome,
            rotulo: 'Nome do motorista',
            maiusculas: TextCapitalization.words,
            erro: _erroNome,
            autofoco: true,
          ),
          const SizedBox(height: 14),
          Campo(
            controle: _cpf,
            rotulo: 'CPF',
            tipo: TipoCampo.cpf,
            dica: '000.000.000-00',
            erro: _erroCpf,
            acaoTeclado: TextInputAction.done,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(onPressed: _gerar, child: const Text('Gerar código')),
    ],
  );
}

/// Código gerado que o motorista ainda não usou.
class _LinhaConvite extends ConsumerWidget {
  const _LinhaConvite({required this.convite});
  final Convite convite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = convite;
    Future<void> cancelar() async {
      final ok = await confirmar(
        context,
        titulo: 'Cancelar o código de ${c.nome}?',
        texto: 'O código ${c.codigo} para de funcionar na hora. Dá para gerar outro depois.',
        botao: 'Cancelar o código',
        perigo: true,
      );
      if (!ok || !context.mounted) return;
      await executar(
        context,
        () => ref.read(equipeProvider.notifier).cancelarConvite(c.id),
        sucesso: 'Código cancelado.',
      );
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: const CircleAvatar(child: Icon(Icons.hourglass_top)),
      title: Text(c.nome, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      subtitle: Text('Código ${c.codigo}  ·  CPF ${cpfTexto(c.cpf)}  ·  vale até ${dataTexto(c.expiraEm)}'),
      trailing: PopupMenuButton<String>(
        tooltip: 'Opções',
        onSelected: (v) {
          if (v == 'ver') mostrarConvite(context, c, ref.read(equipeProvider).requireValue.empresa.nome);
          if (v == 'cancelar') cancelar();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'ver', child: Text('Ver e enviar o código')),
          PopupMenuItem(value: 'cancelar', child: Text('Cancelar o código')),
        ],
      ),
      onTap: () => mostrarConvite(context, c, ref.read(equipeProvider).requireValue.empresa.nome),
    );
  }
}

class _CartaoPedido extends ConsumerWidget {
  const _CartaoPedido({required this.pedido, required this.agora});
  final PedidoEntrada pedido;
  final DateTime agora;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = pedido;
    final cores = context.cores;
    Future<void> decidir(bool aprovar) async {
      if (!aprovar) {
        final ok = await confirmar(
          context,
          titulo: 'Recusar ${p.nome}?',
          texto: 'Ele não entra na empresa. Se for engano, ele pode digitar o código de novo.',
          botao: 'Recusar',
          perigo: true,
        );
        if (!ok || !context.mounted) return;
      }
      await executar(
        context,
        () => ref.read(equipeProvider.notifier).decidirEntrada(p.id, aprovar),
        sucesso: aprovar ? '${p.nome} entrou na empresa.' : 'Pedido recusado.',
      );
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      elevation: 0,
      color: cores.atencaoFundo,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Wrap(
          spacing: 16,
          runSpacing: 10,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(p.nome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                SelectableText('CPF ${cpfTexto(p.cpf)}  ·  ${p.email}', style: const TextStyle(fontSize: 14.5)),
                Text(
                  'Pediu ${quandoTexto(p.pedidoEm, agora)}',
                  style: TextStyle(fontSize: 13.5, color: cores.textoFraco),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(onPressed: () => decidir(false), child: const Text('Recusar')),
                FilledButton.icon(
                  onPressed: () => decidir(true),
                  icon: const Icon(Icons.check),
                  label: const Text('Aprovar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class LinhaMotorista extends StatelessWidget {
  const LinhaMotorista({super.key, required this.motorista, required this.equipe, required this.agora});
  final Motorista motorista;
  final Equipe equipe;
  final DateTime agora;

  @override
  Widget build(BuildContext context) {
    final m = motorista;
    final cores = context.cores;
    final caminhao = equipe.caminhaoAtual(m.id);
    final envio = equipe.ultimoEnvio(m);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: CircleAvatar(
        backgroundColor: m.ativo ? cores.placa : cores.divisor,
        foregroundColor: m.ativo ? cores.placaTexto : cores.textoFraco,
        child: Text(m.nome.isEmpty ? '?' : m.nome.trim()[0].toUpperCase()),
      ),
      title: Text(m.nome, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      subtitle: Text(
        equipe.exclusaoPedida(m) != null
            ? 'Pediu para excluir a conta em ${dataTexto(equipe.exclusaoPedida(m)!)}'
            : '${caminhao == null ? 'sem caminhão' : placaTexto(caminhao.placa)}  ·  último envio ${quandoTexto(envio, agora)}',
        style: equipe.exclusaoPedida(m) != null ? TextStyle(color: cores.negativo) : null,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TelaDetalheMotorista(motoristaId: m.id))),
    );
  }
}
