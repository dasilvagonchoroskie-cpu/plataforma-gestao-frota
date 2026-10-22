import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

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

// ------------------------------------------------------------- criar conta

class TelaCriarConta extends ConsumerStatefulWidget {
  const TelaCriarConta({super.key});

  @override
  ConsumerState<TelaCriarConta> createState() => _TelaCriarContaState();
}

class _TelaCriarContaState extends ConsumerState<TelaCriarConta> with _Ocupado {
  final _email = TextEditingController();

  Future<void> _enviar() async {
    if (!_emailValido(_email.text)) return setState(() => erro = 'Digite um e-mail válido.');
    final ok = await tentar(() => ref.read(servidorProvider).pedirCodigoCadastro(_email.text));
    if (ok && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TelaCodigo(email: _email.text.trim().toLowerCase(), recuperar: false)),
      );
    }
  }

  @override
  Widget build(BuildContext context) => PaginaAcesso(
    titulo: 'Criar conta',
    texto: 'Digite o e-mail que o dono da empresa liberou. Vamos mandar um código de 6 números para ele.',
    filhos: [
      Campo(controle: _email, rotulo: 'E-mail', tipo: TipoCampo.email, autofoco: true),
      MensagemErro(erro),
    ],
    botao: 'Mandar o código',
    aoTocar: _enviar,
    ocupado: ocupado,
  );
}

/// Digita o código que chegou no e-mail (cadastro ou senha esquecida).
class TelaCodigo extends ConsumerStatefulWidget {
  const TelaCodigo({super.key, required this.email, required this.recuperar});
  final String email;
  final bool recuperar;

  @override
  ConsumerState<TelaCodigo> createState() => _TelaCodigoState();
}

class _TelaCodigoState extends ConsumerState<TelaCodigo> with _Ocupado {
  final _codigo = TextEditingController();

  Future<void> _confirmar() async {
    if (_codigo.text.trim().length < 6) return setState(() => erro = 'Digite os 6 números do código.');
    final s = ref.read(servidorProvider);
    final ok = await tentar(
      () => widget.recuperar
          ? s.confirmarCodigoSenha(widget.email, _codigo.text)
          : s.confirmarCodigoCadastro(widget.email, _codigo.text),
    );
    if (!ok || !mounted) return;
    if (widget.recuperar) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TelaNovaSenha(depoisDeRecuperar: true)),
      );
    } else {
      Navigator.popUntil(context, (r) => r.isFirst);
      await ref.read(acessoProvider.notifier).recarregar();
    }
  }

  Future<void> _reenviar() async {
    final s = ref.read(servidorProvider);
    final ok = await tentar(
      () => widget.recuperar ? s.pedirCodigoSenha(widget.email) : s.pedirCodigoCadastro(widget.email),
    );
    if (ok && mounted) mostrarMensagem(context, 'Mandamos outro código.');
  }

  @override
  Widget build(BuildContext context) => PaginaAcesso(
    titulo: 'Digite o código',
    texto: 'Mandamos um código de 6 números para ${widget.email}. Confira também a caixa de spam.',
    filhos: [
      Campo(
        controle: _codigo,
        rotulo: 'Código',
        tipo: TipoCampo.numeros,
        autofoco: true,
        acaoTeclado: TextInputAction.done,
      ),
      MensagemErro(erro),
    ],
    botao: 'Confirmar',
    aoTocar: _confirmar,
    ocupado: ocupado,
    rodape: [
      const SizedBox(height: 8),
      TextButton(onPressed: ocupado ? null : _reenviar, child: const Text('Mandar outro código')),
    ],
  );
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

/// Esqueci a senha: com o código de recuperação, a própria pessoa cria a
/// senha nova. Sem o código: o dono gera uma senha provisória para o gestor;
/// o dono fala com o suporte da plataforma.
class TelaEsqueciSenha extends ConsumerWidget {
  const TelaEsqueciSenha({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => PaginaAcesso(
    titulo: 'Esqueci a senha',
    texto: 'Com o código de recuperação que você anotou no primeiro acesso, você mesmo cria uma senha nova.',
    filhos: const [
      Aviso(
        icone: Icons.help_outline,
        titulo: 'Não tem o código?',
        texto:
            'Gestor: peça ao dono da empresa uma senha provisória (Configurações, Donos e gestores). '
            'Dono: fale com o suporte da plataforma (gestaodefrota2027@gmail.com).',
      ),
    ],
    botao: 'Tenho o código de recuperação',
    aoTocar: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TelaRecuperarComCodigo(
          porCpf: false,
          recuperar: (email, codigo, senha) => ref.read(servidorProvider).recuperarAcesso(email, codigo, senha),
          entrar: (email, senha) async {
            await ref.read(servidorProvider).entrar(email, senha);
            if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
            await ref.read(acessoProvider.notifier).recarregar();
          },
        ),
      ),
    ),
  );
}

/// Senha nova (depois do código de recuperação ou nas configurações).
class TelaNovaSenha extends ConsumerStatefulWidget {
  const TelaNovaSenha({super.key, this.depoisDeRecuperar = false, this.primeiroAcesso = false});
  final bool depoisDeRecuperar;

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
    } else if (widget.depoisDeRecuperar) {
      Navigator.popUntil(context, (r) => r.isFirst);
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
            'Para pedir uma cópia antes disso, escreva para o e-mail acima.',
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
            onPressed: () => excluirEmpresa(context, ref, estado.empresaNome),
            style: TextButton.styleFrom(foregroundColor: context.cores.negativo),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Excluir a conta da empresa e todos os dados'),
          ),
        ],
      ],
    );
  }
}

/// O dono exclui a empresa e todos os dados (digitando o nome da empresa).
Future<void> excluirEmpresa(BuildContext context, WidgetRef ref, String nomeEmpresa) async {
  final ok = await confirmarDigitando(
    context,
    titulo: 'Excluir a empresa e todos os dados?',
    texto:
        'Serão apagados de vez: lançamentos, caminhões, motoristas, gestores e o acesso de todos, inclusive o seu. '
        'Antes, baixe os relatórios (PDF ou planilha) que a empresa precisa guardar. Não dá para desfazer.',
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
