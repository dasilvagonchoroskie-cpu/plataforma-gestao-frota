import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/arquivo_dados.dart';
import '../../dados/link_email.dart';
import '../../dados/provedores.dart';
import '../../servidor/servidor.dart';

/// Moldura das telas de acesso: título, explicação curta, campos e um botão.
/// No computador fica numa coluna estreita no meio da tela.
class PaginaAcesso extends StatelessWidget {
  const PaginaAcesso({
    super.key,
    required this.titulo,
    this.texto,
    required this.filhos,
    this.botao,
    this.aoTocar,
    this.ocupado = false,
    this.voltar = true,
    this.rodape = const [],
  });

  final String titulo;
  final String? texto;
  final List<Widget> filhos;
  final String? botao;
  final VoidCallback? aoTocar;
  final bool ocupado;
  final bool voltar;
  final List<Widget> rodape;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: voltar),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
              children: [
                Text(titulo, style: context.textos.headlineSmall?.copyWith(fontSize: 28)),
                if (texto != null) ...[
                  const SizedBox(height: 10),
                  Text(texto!, style: TextStyle(fontSize: 16.5, height: 1.4, color: context.cores.textoFraco)),
                ],
                const SizedBox(height: 24),
                ...filhos,
                if (botao != null) ...[
                  const SizedBox(height: 24),
                  FilledButton(onPressed: ocupado ? null : aoTocar, child: Text(ocupado ? 'Aguarde...' : botao!)),
                ],
                ...rodape,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MensagemErro extends StatelessWidget {
  const MensagemErro(this.texto, {super.key});
  final String? texto;

  @override
  Widget build(BuildContext context) {
    if (texto == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Aviso(texto: texto!, icone: Icons.error_outline),
    );
  }
}

/// Estado comum das telas de acesso: ocupado e mensagem de erro.
mixin _Ocupado<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool ocupado = false;
  String? erro;

  Future<bool> tentar(Future<void> Function() f) async {
    setState(() {
      ocupado = true;
      erro = null;
    });
    try {
      await f();
      return true;
    } catch (e) {
      if (mounted) setState(() => erro = traduzirErro(e).mensagem);
      return false;
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }
}

bool _emailValido(String e) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e.trim());

// ------------------------------------------------------------------ entrar

class TelaEntrar extends ConsumerStatefulWidget {
  const TelaEntrar({super.key});

  @override
  ConsumerState<TelaEntrar> createState() => _TelaEntrarState();
}

class _TelaEntrarState extends ConsumerState<TelaEntrar> with _Ocupado {
  final _email = TextEditingController();
  final _senha = TextEditingController();

  Future<void> _entrar() async {
    if (!_emailValido(_email.text)) return setState(() => erro = 'Digite o seu e-mail.');
    if (_senha.text.isEmpty) return setState(() => erro = 'Digite a sua senha.');
    final ok = await tentar(() => ref.read(servidorProvider).entrar(_email.text, _senha.text));
    if (ok) await ref.read(acessoProvider.notifier).recarregar();
  }

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
              children: [
                const Placa(rotulo: 'Plataforma de Gestão de Frota', valor: 'Gestor', tamanhoValor: 44),
                const SizedBox(height: 20),
                Text(
                  'Painel do dono e do gestor: fretes, diesel, gastos e vales de cada motorista, '
                  'chegando direto do celular deles.',
                  style: TextStyle(fontSize: 17, height: 1.4, color: cores.textoFraco),
                ),
                const SizedBox(height: 28),
                Campo(controle: _email, rotulo: 'E-mail', tipo: TipoCampo.email),
                const SizedBox(height: 14),
                Campo(controle: _senha, rotulo: 'Senha', tipo: TipoCampo.senha, acaoTeclado: TextInputAction.done),
                MensagemErro(erro),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: ocupado ? null : _entrar,
                  icon: const Icon(Icons.login),
                  label: Text(ocupado ? 'Entrando...' : 'Entrar'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaEsqueciSenha())),
                  child: const Text('Esqueci a senha'),
                ),
                const Divider(height: 36),
                Text(
                  'Primeira vez? O dono da empresa cria o seu acesso no painel e passa uma senha provisória. '
                  'No primeiro login você cria a sua senha.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.35, color: cores.textoFraco),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Depois de confirmar o e-mail: nome e senha. Se o e-mail estiver liberado
/// pelo dono, a pessoa já entra na empresa.
class TelaCompletarCadastro extends ConsumerStatefulWidget {
  const TelaCompletarCadastro({super.key, required this.email});
  final String email;

  @override
  ConsumerState<TelaCompletarCadastro> createState() => _TelaCompletarCadastroState();
}

class _TelaCompletarCadastroState extends ConsumerState<TelaCompletarCadastro> with _Ocupado {
  final _nome = TextEditingController();
  final _senha = TextEditingController();

  Future<void> _salvar() async {
    if (_nome.text.trim().length < 2) return setState(() => erro = 'Escreva o seu nome.');
    if (!senhaAceita(_senha.text)) return setState(() => erro = mensagemSenha);
    final s = ref.read(servidorProvider);
    final ok = await tentar(() async {
      try {
        await s.completarCadastro(_nome.text);
      } on ErroServidor catch (e) {
        if (e.codigo == 'cpf_obrigatorio') {
          throw ErroServidor(
            'O e-mail ${widget.email} ainda não foi liberado. Peça ao dono da empresa para '
            'incluir este e-mail no painel (Configurações, Gestores) e tente de novo.',
          );
        }
        rethrow;
      }
      await s.definirSenha(_senha.text);
    });
    if (ok) await ref.read(acessoProvider.notifier).recarregar();
  }

  @override
  Widget build(BuildContext context) => PaginaAcesso(
    titulo: 'Seus dados',
    texto: 'E-mail confirmado: ${widget.email}. Agora o seu nome e uma senha para entrar das próximas vezes.',
    voltar: false,
    filhos: [
      Campo(controle: _nome, rotulo: 'Seu nome', maiusculas: TextCapitalization.words, autofoco: true),
      const SizedBox(height: 14),
      Campo(
        controle: _senha,
        rotulo: 'Crie uma senha',
        tipo: TipoCampo.senha,
        ajuda: ajudaSenha,
      ),
      MensagemErro(erro),
    ],
    botao: 'Entrar no painel',
    aoTocar: _salvar,
    ocupado: ocupado,
    rodape: [
      const SizedBox(height: 8),
      TextButton(onPressed: () => ref.read(acessoProvider.notifier).sair(), child: const Text('Usar outro e-mail')),
    ],
  );
}

// ----------------------------------------------------------- esqueci a senha

/// Esqueci a senha: o link para criar a senha nova vai para o e-mail.
class TelaEsqueciSenha extends ConsumerWidget {
  const TelaEsqueciSenha({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => TelaPedirLinkSenha(
    porCpf: false,
    pedir: (email) => ref.read(servidorProvider).pedirLinkSenha(email),
    semEmail:
        'Gestor: peça ao dono da empresa uma senha provisória (Configurações, Donos e gestores). '
        'Dono: fale com o suporte da plataforma (gestaodefrota2027@gmail.com).',
  );
}

/// Abre o link que chegou por e-mail: criar a senha nova (dono, gestor ou
/// motorista) ou confirmar o e-mail do motorista. Depois sai da conta: a
/// pessoa entra de novo, com a senha nova, no app dela.
class TelaLinkDoEmail extends ConsumerStatefulWidget {
  const TelaLinkDoEmail({super.key, required this.link});
  final LinkDoEmail link;

  @override
  ConsumerState<TelaLinkDoEmail> createState() => _TelaLinkDoEmailState();
}

enum _FaseLink { abrindo, senha, pronto, erro }

class _TelaLinkDoEmailState extends ConsumerState<TelaLinkDoEmail> with _Ocupado {
  final _senha = TextEditingController();
  var _fase = _FaseLink.abrindo;
  bool get _criarSenha => widget.link.tipo == TipoLink.senha;

  @override
  void initState() {
    super.initState();
    _abrir();
  }

  @override
  void dispose() {
    _senha.dispose();
    super.dispose();
  }

  Future<void> _abrir() async {
    final s = ref.read(servidorProvider);
    try {
      await s.abrirLinkDoEmail(widget.link.tokenHash, senha: _criarSenha);
      if (!_criarSenha) await s.sair();
      if (mounted) setState(() => _fase = _criarSenha ? _FaseLink.senha : _FaseLink.pronto);
    } catch (e) {
      if (mounted) {
        setState(() {
          _fase = _FaseLink.erro;
          erro = traduzirErro(e).mensagem;
        });
      }
    }
  }

  Future<void> _salvar() async {
    if (!senhaAceita(_senha.text)) return setState(() => erro = mensagemSenha);
    final s = ref.read(servidorProvider);
    final ok = await tentar(() => s.definirSenha(_senha.text));
    if (!ok || !mounted) return;
    // Senha nova: encerra as sessões abertas em outros aparelhos.
    await s.sair(todosOsAparelhos: true);
    if (mounted) setState(() => _fase = _FaseLink.pronto);
  }

  Future<void> _irParaEntrar() async {
    ref.read(linkDoEmailProvider.notifier).concluir();
    await ref.read(acessoProvider.notifier).recarregar();
  }

  @override
  Widget build(BuildContext context) {
    switch (_fase) {
      case _FaseLink.abrindo:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case _FaseLink.erro:
        return PaginaAcesso(
          titulo: 'Este link não vale mais',
          texto: erro,
          voltar: false,
          filhos: const [
            Aviso(
              icone: Icons.help_outline,
              titulo: 'Por que acontece',
              texto:
                  'Cada pedido novo cancela o link anterior: use só o e-mail mais novo (ele pode levar 1 ou 2 '
                  'minutos para chegar). O link também vence em 1 hora e funciona uma vez só.',
            ),
          ],
          botao: 'Pedir outro link',
          aoTocar: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TelaEsqueciSenha())),
          rodape: [
            const SizedBox(height: 8),
            TextButton(onPressed: _irParaEntrar, child: const Text('Ir para a tela de entrar')),
          ],
        );
      case _FaseLink.senha:
        return PaginaAcesso(
          titulo: 'Crie a senha nova',
          texto: 'Escolha a senha que você vai usar para entrar daqui para frente.',
          voltar: false,
          filhos: [
            Campo(controle: _senha, rotulo: 'Senha nova', tipo: TipoCampo.senha, autofoco: true, ajuda: ajudaSenha),
            MensagemErro(erro),
          ],
          botao: 'Salvar a senha nova',
          aoTocar: _salvar,
          ocupado: ocupado,
        );
      case _FaseLink.pronto:
        return PaginaAcesso(
          titulo: _criarSenha ? 'Senha nova criada' : 'E-mail confirmado',
          texto: _criarSenha
              ? 'Pronto! Agora entre com a senha nova. Por segurança, quem estava logado em outro aparelho '
                    'precisa entrar de novo.'
              : 'Pronto! Se um dia esquecer a senha, o link para criar outra chega neste e-mail.',
          voltar: false,
          filhos: const [
            Aviso(
              icone: Icons.info_outline,
              texto:
                  'Motorista: abra o app Frota Motorista e entre com o CPF e a senha. '
                  'Dono e gestor: entrem com o e-mail e a senha, aqui no painel ou no app Frota Gestor.',
            ),
          ],
          botao: 'Ir para a tela de entrar',
          aoTocar: _irParaEntrar,
        );
    }
  }
}

/// Senha nova (primeiro acesso com senha provisória ou nas configurações).
class TelaNovaSenha extends ConsumerStatefulWidget {
  const TelaNovaSenha({super.key, this.primeiroAcesso = false});

  /// Entrou com senha provisória: tela inicial obrigatória, sem voltar.
  final bool primeiroAcesso;

  @override
  ConsumerState<TelaNovaSenha> createState() => _TelaNovaSenhaState();
}

class _TelaNovaSenhaState extends ConsumerState<TelaNovaSenha> with _Ocupado {
  final _senha = TextEditingController();

  Future<void> _salvar() async {
    if (!senhaAceita(_senha.text)) return setState(() => erro = mensagemSenha);
    final ok = await tentar(() => ref.read(servidorProvider).definirSenha(_senha.text));
    if (!ok || !mounted) return;
    if (widget.primeiroAcesso) {
      await ref.read(acessoProvider.notifier).recarregar();
    } else {
      Navigator.pop(context);
      mostrarMensagem(context, 'Senha trocada.');
    }
  }

  @override
  Widget build(BuildContext context) => PaginaAcesso(
    titulo: widget.primeiroAcesso ? 'Crie a sua senha' : 'Senha nova',
    texto: widget.primeiroAcesso
        ? 'Você entrou com uma senha provisória. Escolha agora a senha que você vai usar daqui para frente.'
        : 'Escolha a senha que você vai usar para entrar.',
    voltar: !widget.primeiroAcesso,
    filhos: [
      Campo(
        controle: _senha,
        rotulo: 'Senha nova',
        tipo: TipoCampo.senha,
        autofoco: true,
        ajuda: ajudaSenha,
      ),
      MensagemErro(erro),
    ],
    botao: 'Salvar senha',
    aoTocar: _salvar,
    ocupado: ocupado,
    rodape: [
      if (widget.primeiroAcesso) ...[
        const SizedBox(height: 8),
        TextButton(onPressed: () => ref.read(acessoProvider.notifier).sair(), child: const Text('Sair')),
      ],
    ],
  );
}

// --------------------------------------------------- contas sem acesso

class TelaSemAcesso extends ConsumerWidget {
  const TelaSemAcesso({super.key, required this.motorista, required this.email});
  final bool motorista;
  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PaginaAcesso(
    titulo: motorista ? 'Esta conta é de motorista' : 'Acesso não liberado',
    texto: motorista
        ? 'O e-mail $email está cadastrado como motorista. Use o app Frota Motorista no celular. '
              'Este painel é só para o dono e os gestores.'
        : 'O e-mail $email não está liberado em nenhuma empresa agora. Peça ao dono para incluir '
              'você em Configurações, Gestores, e depois toque em "Verificar de novo".',
    voltar: false,
    filhos: const [],
    botao: motorista ? null : 'Verificar de novo',
    aoTocar: () => ref.read(acessoProvider.notifier).recarregar(),
    rodape: [
      const SizedBox(height: 8),
      OutlinedButton(onPressed: () => ref.read(acessoProvider.notifier).sair(), child: const Text('Sair')),
    ],
  );
}

class TelaSemInternet extends ConsumerWidget {
  const TelaSemInternet({super.key, required this.mensagem, required this.tentarDeNovo});
  final String mensagem;
  final VoidCallback tentarDeNovo;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PaginaAcesso(
    titulo: 'Não deu para abrir',
    texto: mensagem,
    voltar: false,
    filhos: const [],
    botao: 'Tentar de novo',
    aoTocar: tentarDeNovo,
    rodape: [
      const SizedBox(height: 8),
      TextButton(onPressed: () => ref.read(acessoProvider.notifier).sair(), child: const Text('Sair da conta')),
    ],
  );
}

// ---------------------------------------------------- acesso encerrado

/// A plataforma encerrou o acesso da empresa (fim do teste ou bloqueio). O
/// dono ainda pode excluir a conta da empresa e todos os dados.
class TelaAcessoEncerrado extends ConsumerWidget {
  const TelaAcessoEncerrado({super.key, required this.estado});
  final EstadoAcesso estado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apagaEm = estado.excluirEm;
    return PaginaAcesso(
      titulo: 'Acesso encerrado',
      texto:
          'O acesso da ${estado.empresaNome.isEmpty ? 'empresa' : estado.empresaNome} à plataforma foi encerrado. '
          'Para continuar usando, fale com a Fortaleza Digital Security (gestaodefrota2027@gmail.com).',
      voltar: false,
      filhos: [
        if ((estado.mensagem ?? '').isNotEmpty) Aviso(icone: Icons.lock_clock_outlined, texto: 'Motivo: ${estado.mensagem}'),
        if (apagaEm != null) ...[
          const SizedBox(height: 12),
          Nota(
            'Os dados ficam guardados até ${dataTexto(apagaEm)} e depois são apagados de vez. '
            '${estado.dono ? 'Antes disso, baixe aqui o PDF com todos os dados da empresa.' : 'Antes disso, o dono baixa o PDF com todos os dados da empresa.'}',
          ),
        ],
        if (estado.dono) ...[
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () => baixarDadosEmpresa(context, ref, doServidor: true),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Baixar todos os dados (PDF)'),
          ),
        ],
      ],
      botao: 'Verificar de novo',
      aoTocar: () => ref.read(acessoProvider.notifier).recarregar(),
      rodape: [
        const SizedBox(height: 8),
        OutlinedButton(onPressed: () => ref.read(acessoProvider.notifier).sair(), child: const Text('Sair')),
        if (estado.dono) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => excluirEmpresa(context, ref, estado.empresaNome, doServidor: true),
            style: TextButton.styleFrom(foregroundColor: context.cores.negativo),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Excluir a conta da empresa e todos os dados'),
          ),
        ],
      ],
    );
  }
}

/// O dono exclui a empresa e todos os dados. Antes, sempre, o PDF com todos
/// os dados (regra aprovada pelo dono); depois, digitar o nome da empresa.
/// [doServidor]: acesso encerrado (os dados do PDF vêm da exportação do dono).
Future<void> excluirEmpresa(BuildContext context, WidgetRef ref, String nomeEmpresa, {bool doServidor = false}) async {
  final pdf = await primeiroOPdf(
    context,
    quem: 'da empresa',
    gerar: () => baixarDadosEmpresa(context, ref, doServidor: doServidor),
  );
  if (!pdf || !context.mounted) return;
  final ok = await confirmarDigitando(
    context,
    titulo: 'Excluir a empresa e todos os dados?',
    texto:
        'O PDF com todos os dados já foi gerado. Agora serão apagados de vez: lançamentos, caminhões, motoristas, '
        'gestores e o acesso de todos, inclusive o seu. Não dá para desfazer.',
    palavra: nomeEmpresa,
    botao: 'Excluir tudo',
  );
  if (!ok || !context.mounted) return;
  try {
    Navigator.of(context).popUntil((r) => r.isFirst);
    await ref.read(acessoProvider.notifier).excluirEmpresa(nomeEmpresa);
    if (context.mounted) mostrarMensagem(context, 'A conta da empresa e todos os dados foram excluídos.');
  } catch (e) {
    if (context.mounted) mostrarMensagem(context, traduzirErro(e).mensagem);
  }
}
