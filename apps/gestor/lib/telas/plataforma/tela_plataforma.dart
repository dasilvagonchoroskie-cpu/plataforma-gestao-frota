import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:share_plus/share_plus.dart';
import 'package:visual/visual.dart';

import '../../componentes/comuns.dart';
import '../../config.dart';
import '../../dados/provedores.dart';
import '../../servidor/servidor.dart';

/// Uma empresa na lista da Plataforma.
class EmpresaPlataforma {
  const EmpresaPlataforma({
    required this.id,
    required this.nome,
    required this.donoNome,
    required this.donoEmail,
    required this.situacao,
    this.acessoAte,
    this.motivoBloqueio,
    this.excluirEm,
    this.limiteCaminhoes = 0,
    this.motoristas = 0,
    this.caminhoes = 0,
    this.ultimoEnvio,
    this.primeiroAcessoPendente = false,
  });

  final String id;
  final String nome;
  final String donoNome;
  final String donoEmail;

  /// liberada, teste, teste_vencido, bloqueada ou excluida.
  final String situacao;
  final DateTime? acessoAte;
  final String? motivoBloqueio;
  final DateTime? excluirEm;
  final int limiteCaminhoes;
  final int motoristas;
  final int caminhoes;
  final DateTime? ultimoEnvio;

  /// O dono ainda não trocou a senha provisória.
  final bool primeiroAcessoPendente;

  static DateTime? _data(Object? v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();
  static int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  factory EmpresaPlataforma.deMapa(Map<String, Object?> m) => EmpresaPlataforma(
    id: '${m['id']}',
    nome: '${m['nome'] ?? ''}',
    donoNome: '${m['dono_nome'] ?? ''}',
    donoEmail: '${m['dono_email'] ?? ''}',
    situacao: '${m['situacao'] ?? 'liberada'}',
    acessoAte: _data(m['acesso_ate']),
    motivoBloqueio: m['motivo_bloqueio'] as String?,
    excluirEm: _data(m['excluir_em']),
    limiteCaminhoes: _int(m['limite_caminhoes']),
    motoristas: _int(m['motoristas']),
    caminhoes: _int(m['caminhoes']),
    ultimoEnvio: _data(m['ultimo_envio']),
    primeiroAcessoPendente: m['dono_primeiro_acesso_pendente'] == true,
  );

  bool get excluida => situacao == 'excluida';

  String get situacaoTexto => switch (situacao) {
    'teste' => acessoAte == null ? 'Em teste' : 'Em teste até ${dataTexto(acessoAte!)}',
    'teste_vencido' => 'Teste vencido',
    'bloqueada' => 'Bloqueada',
    'excluida' => 'Excluída',
    _ => 'Liberada, sem prazo',
  };
}

/// Recado para mandar ao dono da empresa, com o acesso e o primeiro passo.
String recadoDono({required String dono, required String empresa, required String email, required String senha}) =>
    'Olá, ${dono.split(' ').first}! A $empresa já está cadastrada na Plataforma de Gestão de Frota.\n\n'
    '1) Instale o app Frota Gestor (vou te mandar o arquivo) ou abra o painel no computador: $enderecoPainel\n'
    '2) Entre com o e-mail $email e a senha provisória $senha\n'
    '3) No primeiro acesso, crie a sua senha.\n\n'
    'Se um dia esquecer a senha, toque em "Esqueci a senha": o link chega no seu e-mail.\n'
    'Dúvidas: gestaodefrota2027@gmail.com';

final empresasPlataformaProvider = FutureProvider.autoDispose<List<EmpresaPlataforma>>((ref) async {
  final lista = await ref.read(servidorProvider).plataformaEmpresas();
  return [for (final m in lista) EmpresaPlataforma.deMapa(m)];
});

/// Área da Plataforma: só o super administrador vê (o banco confere de novo
/// em cada ação). [sozinha]: a conta não é de nenhuma empresa (tela inicial).
class TelaPlataforma extends ConsumerWidget {
  const TelaPlataforma({super.key, this.sozinha = false});
  final bool sozinha;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final empresas = ref.watch(empresasPlataformaProvider);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !sozinha,
        title: const Text('Plataforma'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(empresasPlataformaProvider),
          ),
          if (sozinha)
            IconButton(
              tooltip: 'Sair',
              icon: const Icon(Icons.logout),
              onPressed: () => ref.read(acessoProvider.notifier).sair(),
            ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'nova_empresa',
        onPressed: () => cadastrarEmpresa(context, ref),
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('Cadastrar empresa'),
      ),
      body: empresas.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Aviso(texto: traduzirErro(e).mensagem, icone: Icons.error_outline),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(empresasPlataformaProvider),
                  child: const Text('Tentar de novo'),
                ),
              ],
            ),
          ),
        ),
        data: (lista) {
          final ativas = lista.where((e) => !e.excluida).toList();
          return ListaCentral(
            largura: 900,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'Super administrador. Aqui você cadastra as transportadoras e cuida do acesso delas. '
                  'Cada empresa entra com o e-mail do dono dela.',
                  style: TextStyle(fontSize: 15, height: 1.35, color: context.cores.textoFraco),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TituloSecao('Empresas (${ativas.length})'),
              ),
              if (ativas.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Nota('Nenhuma empresa ainda. Toque em "Cadastrar empresa".'),
                ),
              for (final e in ativas) _LinhaEmpresa(empresa: e),
            ],
          );
        },
      ),
    );
  }
}

class _LinhaEmpresa extends ConsumerWidget {
  const _LinhaEmpresa({required this.empresa});
  final EmpresaPlataforma empresa;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = empresa;
    final cores = context.cores;
    final cor = switch (e.situacao) {
      'bloqueada' || 'teste_vencido' => cores.negativo,
      'teste' => cores.atencao,
      _ => cores.positivo,
    };
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => acoesEmpresa(context, ref, e),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(e.nome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  Selo(e.situacaoTexto, cor: cor),
                ],
              ),
              const SizedBox(height: 4),
              Text('Dono: ${e.donoNome.isEmpty ? '-' : e.donoNome} · ${e.donoEmail}',
                  style: TextStyle(fontSize: 14.5, color: cores.textoFraco)),
              const SizedBox(height: 2),
              Text(
                '${plural(e.motoristas, 'motorista', 'motoristas')} · '
                '${e.caminhoes} de ${e.limiteCaminhoes} caminhões · '
                '${e.ultimoEnvio == null ? 'nenhum envio ainda' : 'último envio ${dataTexto(e.ultimoEnvio!)}'}',
                style: TextStyle(fontSize: 14, color: cores.textoFraco),
              ),
              if (e.primeiroAcessoPendente) ...[
                const SizedBox(height: 6),
                const Etiqueta('Esperando o primeiro acesso do dono'),
              ],
              if (e.situacao == 'bloqueada' && (e.motivoBloqueio ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Motivo: ${e.motivoBloqueio}', style: TextStyle(fontSize: 14, color: cores.negativo)),
              ],
              if (e.excluirEm != null && e.situacao != 'liberada' && e.situacao != 'teste') ...[
                const SizedBox(height: 2),
                Text('Os dados serão apagados em ${dataTexto(e.excluirEm!)} se não for liberada.',
                    style: TextStyle(fontSize: 13.5, color: cores.textoFraco)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Ações de uma empresa: prazo, liberar, bloquear e senha nova do dono.
Future<void> acoesEmpresa(BuildContext context, WidgetRef ref, EmpresaPlataforma e) async {
  final escolha = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(title: Text(e.nome, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(e.situacaoTexto)),
          ListTile(
            leading: const Icon(Icons.event_available_outlined),
            title: const Text('Dar 30 dias de teste (a partir de hoje)'),
            onTap: () => Navigator.pop(ctx, 'teste30'),
          ),
          ListTile(
            leading: const Icon(Icons.lock_open_outlined),
            title: const Text('Liberar sem prazo (cliente contratou)'),
            onTap: () => Navigator.pop(ctx, 'liberar'),
          ),
          ListTile(
            leading: const Icon(Icons.key_outlined),
            title: const Text('Gerar senha provisória para o dono'),
            subtitle: const Text('Para quem perdeu o acesso ao e-mail'),
            onTap: () => Navigator.pop(ctx, 'senha'),
          ),
          if (e.situacao != 'bloqueada')
            ListTile(
              leading: Icon(Icons.block, color: ctx.cores.negativo),
              title: Text('Bloquear o acesso', style: TextStyle(color: ctx.cores.negativo)),
              subtitle: const Text('Os dados são apagados 30 dias depois, se não for liberada'),
              onTap: () => Navigator.pop(ctx, 'bloquear'),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (escolha == null || !context.mounted) return;
  final s = ref.read(servidorProvider);
  switch (escolha) {
    case 'teste30':
      if (await executar(context, () => s.plataformaLiberar(e.id, dias: 30), sucesso: 'Prazo de 30 dias dado.')) {
        ref.invalidate(empresasPlataformaProvider);
      }
    case 'liberar':
      final ok = await confirmar(
        context,
        titulo: 'Liberar sem prazo?',
        texto: 'A ${e.nome} passa a usar a plataforma sem data para acabar (o bloqueio, se tiver, sai).',
        botao: 'Liberar',
      );
      if (ok && context.mounted && await executar(context, () => s.plataformaLiberar(e.id), sucesso: 'Empresa liberada.')) {
        ref.invalidate(empresasPlataformaProvider);
      }
    case 'bloquear':
      final motivo = await _pedirMotivo(context, e);
      if (motivo != null && context.mounted &&
          await executar(context, () => s.plataformaBloquear(e.id, motivo), sucesso: 'Acesso bloqueado.')) {
        ref.invalidate(empresasPlataformaProvider);
      }
    case 'senha':
      final ok = await confirmar(
        context,
        titulo: 'Gerar senha provisória?',
        texto: 'A senha atual do dono (${e.donoEmail}) deixa de valer. Ele entra com a provisória e cria outra '
            'no primeiro acesso.',
        botao: 'Gerar',
      );
      if (!ok || !context.mounted) return;
      Map<String, Object?>? r;
      if (!await executar(context, () async => r = await s.plataformaNovaSenhaDono(e.id)) || !context.mounted) return;
      await mostrarAcessoDono(
        context,
        empresa: e.nome,
        dono: '${r?['dono_nome'] ?? e.donoNome}',
        email: '${r?['dono_email'] ?? e.donoEmail}',
        senha: '${r?['senha_provisoria']}',
      );
      ref.invalidate(empresasPlataformaProvider);
  }
}

Future<String?> _pedirMotivo(BuildContext context, EmpresaPlataforma e) {
  final controle = TextEditingController(text: 'Falta de pagamento.');
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Bloquear a ${e.nome}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ninguém da empresa entra mais. Se não for liberada, os dados são apagados em 30 dias.'),
          const SizedBox(height: 12),
          TextField(controller: controle, decoration: const InputDecoration(labelText: 'Motivo (o dono vê)')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: ctx.cores.negativo),
          onPressed: () {
            final m = controle.text.trim();
            if (m.length >= 3) Navigator.pop(ctx, m);
          },
          child: const Text('Bloquear'),
        ),
      ],
    ),
  );
}

/// Cadastro da empresa (e do dono); no fim, mostra o acesso para mandar ao dono.
Future<void> cadastrarEmpresa(BuildContext context, WidgetRef ref) async {
  final cadastrou = await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (_) => const TelaCadastrarEmpresa()),
  );
  if (cadastrou == true) ref.invalidate(empresasPlataformaProvider);
}

class TelaCadastrarEmpresa extends ConsumerStatefulWidget {
  const TelaCadastrarEmpresa({super.key});

  @override
  ConsumerState<TelaCadastrarEmpresa> createState() => _TelaCadastrarEmpresaState();
}

class _TelaCadastrarEmpresaState extends ConsumerState<TelaCadastrarEmpresa> {
  final _empresa = TextEditingController();
  final _dono = TextEditingController();
  final _email = TextEditingController();
  final _limite = TextEditingController(text: '5');
  int? _dias = 30;
  String? _erro;
  bool _ocupado = false;

  static const _prazos = <int?>[7, 15, 30, 60, 90, null];

  @override
  void dispose() {
    _empresa.dispose();
    _dono.dispose();
    _email.dispose();
    _limite.dispose();
    super.dispose();
  }

  Future<void> _cadastrar() async {
    final limite = int.tryParse(_limite.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    String? erro;
    if (_empresa.text.trim().length < 2) {
      erro = 'Escreva o nome da empresa.';
    } else if (_dono.text.trim().length < 2) {
      erro = 'Escreva o nome do dono.';
    } else if (!emailValido(_email.text)) {
      erro = 'Confira o e-mail do dono.';
    } else if (limite < 1 || limite > 1000) {
      erro = 'O limite de caminhões vai de 1 a 1000.';
    }
    setState(() => _erro = erro);
    if (erro != null) return;
    setState(() => _ocupado = true);
    try {
      final r = await ref.read(servidorProvider).plataformaCriarEmpresa(
        nome: _empresa.text.trim(),
        donoNome: _dono.text.trim(),
        donoEmail: _email.text.trim().toLowerCase(),
        diasTeste: _dias,
        limiteCaminhoes: limite,
      );
      if (!mounted) return;
      await mostrarAcessoDono(
        context,
        empresa: '${r['nome']}',
        dono: '${r['dono_nome']}',
        email: '${r['dono_email']}',
        senha: '${r['senha_provisoria']}',
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _erro = traduzirErro(e).mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cadastrar empresa')),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              Text(
                'A empresa entra com o e-mail do dono dela. O app gera uma senha provisória, que ele troca no '
                'primeiro acesso.',
                style: TextStyle(fontSize: 16, height: 1.4, color: context.cores.textoFraco),
              ),
              const SizedBox(height: 20),
              Campo(controle: _empresa, rotulo: 'Nome da empresa', maiusculas: TextCapitalization.words, autofoco: true),
              const SizedBox(height: 14),
              Campo(controle: _dono, rotulo: 'Nome do dono', maiusculas: TextCapitalization.words),
              const SizedBox(height: 14),
              Campo(
                controle: _email,
                rotulo: 'E-mail do dono',
                tipo: TipoCampo.email,
                ajuda: 'É o login dele. O link de senha esquecida chega neste e-mail.',
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int?>(
                isExpanded: true,
                initialValue: _dias,
                decoration: const InputDecoration(labelText: 'Prazo de teste'),
                items: [
                  for (final d in _prazos)
                    DropdownMenuItem(
                      value: d,
                      child: Text(d == null ? 'Sem prazo (já contratou)' : '$d dias', overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _dias = v),
              ),
              const SizedBox(height: 14),
              Campo(controle: _limite, rotulo: 'Limite de caminhões', tipo: TipoCampo.numeros,
                  acaoTeclado: TextInputAction.done),
              if (_erro != null) ...[const SizedBox(height: 16), Aviso(texto: _erro!, icone: Icons.error_outline)],
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: RodapeBotao(
      texto: _ocupado ? 'Aguarde...' : 'Cadastrar empresa',
      aoTocar: _ocupado ? null : _cadastrar,
    ),
  );
}

/// Mostra o acesso do dono (aparece uma vez só) com o recado pronto.
Future<void> mostrarAcessoDono(
  BuildContext context, {
  required String empresa,
  required String dono,
  required String email,
  required String senha,
}) {
  final recado = recadoDono(dono: dono, empresa: empresa, email: email, senha: senha);
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text('Acesso de ${dono.split(' ').first}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$empresa · $email', style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 14),
            const Text('Senha provisória (aparece só agora):'),
            const SizedBox(height: 6),
            Center(
              child: SelectableText(senha, style: estiloNumero(32, peso: FontWeight.w700).copyWith(letterSpacing: 3)),
            ),
            const SizedBox(height: 14),
            const Nota('Mande o recado pelo WhatsApp, junto com o arquivo do app Frota Gestor. No primeiro acesso ele '
                'cria a senha dele.'),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: recado));
            if (ctx.mounted) mostrarMensagem(ctx, 'Recado copiado. Cole no WhatsApp do dono.');
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
