import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/arquivo_dados.dart';
import '../../componentes/comuns.dart';
import '../../config.dart';
import '../../dados/equipe.dart';
import '../../dados/modelos.dart';
import '../../dados/provedores.dart';
import '../acesso/telas_acesso.dart';
import '../casca.dart';
import '../plataforma/tela_plataforma.dart';
import 'tela_config_paradas.dart';
import 'tela_modalidades.dart';

/// Configurações: dados e regras da empresa, categorias de gasto, gestores,
/// celulares dos motoristas e a conta de quem está usando.
class TelaConfiguracoes extends ConsumerWidget {
  const TelaConfiguracoes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = assistirEquipe(ref);
    final acesso = ref.watch(acessoProvider).value;
    final cores = context.cores;
    final emp = e.empresa;
    final cfg = emp.configuracao;
    final largo = telaLarga(context);

    void abrir(Widget tela) => Navigator.push(context, MaterialPageRoute(builder: (_) => tela));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        leading: largo
            ? null
            : IconButton(
                tooltip: 'Voltar',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => ref.read(secaoProvider.notifier).ir(Secao.painel),
              ),
        actions: const [BotaoAtualizar(), SizedBox(width: 4)],
      ),
      body: ListaCentral(
        largura: 760,
        children: [
          const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: TituloSecao('Empresa', espacoAcima: 12)),
          ListTile(
            leading: const Icon(Icons.business_outlined),
            title: Text(emp.nome),
            subtitle: Text(
              [
                if ((emp.documento ?? '').isNotEmpty) emp.documento!,
                'plano ${emp.plano}, até ${emp.limiteCaminhoes} caminhões',
                switch (emp.status) {
                  'ativa' => 'ativa',
                  'suspensa' => 'suspensa',
                  _ => 'em teste',
                },
                if (emp.acessoAte != null) 'acesso até ${dataTexto(emp.acessoAte!)}',
              ].join('  ·  '),
            ),
            trailing: e.souDono ? const Icon(Icons.edit_outlined) : null,
            onTap: e.souDono ? () => showDialog<void>(context: context, builder: (_) => const _FormEmpresa()) : null,
          ),
          ListTile(
            leading: const Icon(Icons.rule),
            title: const Text('Regras de acerto com o motorista'),
            subtitle: Text(
              'Comissão padrão ${percentualTexto(cfg.percentualComissaoPadrao)}% '
              '${cfg.comissaoSobreBrutoPadrao ? 'sobre frete + pedágio' : 'sobre o frete'}; '
              '${cfg.gastosDescontamDoLiquido ? 'gastos por conta do motorista' : 'gastos pagos pela empresa'}; '
              '${cfg.valeDescontaDoLiquido ? 'vale desconta' : 'vale não desconta'}.',
            ),
            trailing: e.souDono ? const Icon(Icons.edit_outlined) : null,
            onTap: e.souDono ? () => abrir(const TelaRegras()) : null,
          ),
          ListTile(
            leading: const Icon(Icons.alt_route),
            title: const Text('Modalidades de operação'),
            subtitle: Text(
              e.modalidadesAtivas.isEmpty
                  ? 'Graneleiro'
                  : '${e.modalidadesAtivas.map((m) => m.nome).join(', ')}. Campos de cada uma.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => abrir(const TelaModalidades()),
          ),
          ListTile(
            leading: const Icon(Icons.pause_circle_outline),
            title: const Text('Registro de paradas'),
            subtitle: Text(
              emp.paradasAtivas
                  ? 'Ligado. Limite sem descanso: ${emp.limiteSemDescansoMinutos == null ? '—' : limiteTexto(emp.limiteSemDescansoMinutos!)}.'
                  : 'Desligado (os motoristas não veem a aba).',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => abrir(const TelaConfigParadas()),
          ),
          if (!e.souDono)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Nota('Só o dono muda os dados, as regras, as modalidades e as paradas da empresa.'),
            ),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: TituloSecao('Cadastros')),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Categorias de gasto'),
            subtitle: Text('${e.categorias.where((c) => c.ativa).length} em uso'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => abrir(const TelaCategorias()),
          ),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: const Text('Donos e gestores'),
            subtitle: Text(
              e.souDono
                  ? 'Quem pode entrar neste painel'
                  : '${e.acessos.where((a) => a.ativo).length} com acesso (só o dono muda)',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => abrir(const TelaGestores()),
          ),
          ListTile(
            leading: const Icon(Icons.smartphone),
            title: const Text('Celulares dos motoristas'),
            subtitle: Text('${e.dispositivos.where((d) => !d.revogado).length} enviando dados'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => abrir(const TelaAparelhos()),
          ),
          if (acesso?.adminPlataforma == true) ...[
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: TituloSecao('Plataforma')),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: const Text('Área da Plataforma'),
              subtitle: const Text('Cadastrar empresas e cuidar do acesso delas (super administrador)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => abrir(const TelaPlataforma()),
            ),
          ],
          const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: TituloSecao('Minha conta')),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(e.eu.nome.isEmpty ? (acesso?.nome ?? '') : e.eu.nome),
            subtitle: Text('${acesso?.email ?? e.eu.email}  ·  ${e.souDono ? 'dono' : 'gestor'}'),
          ),
          ListTile(
            leading: const Icon(Icons.password),
            title: const Text('Trocar a senha'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => abrir(const TelaNovaSenha()),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Termos de Uso'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, TelaTextoLegal.rota('Termos de Uso', termosDeUso)),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Política de Privacidade'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, TelaTextoLegal.rota('Política de Privacidade', politicaDePrivacidade)),
          ),
          ListTile(
            leading: Icon(Icons.logout, color: cores.negativo),
            title: Text('Sair', style: TextStyle(color: cores.negativo)),
            onTap: () async {
              final ok = await confirmar(
                context,
                titulo: 'Sair do painel?',
                texto: 'Para voltar, entre com o e-mail e a senha.',
                botao: 'Sair',
              );
              if (ok) await ref.read(acessoProvider.notifier).sair();
            },
          ),
          if (e.souDono) ...[
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: TituloSecao('Encerrar')),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Baixar todos os dados da empresa (PDF)'),
              subtitle: const Text('Caminhões e, de cada motorista, o cadastro e todo o histórico.'),
              onTap: () => baixarDadosEmpresa(context, ref),
            ),
            ListTile(
              leading: Icon(Icons.delete_forever_outlined, color: cores.negativo),
              title: Text('Excluir a conta da empresa e todos os dados', style: TextStyle(color: cores.negativo)),
              subtitle: const Text('Para quem não vai continuar com a plataforma. Não dá para desfazer.'),
              onTap: () => excluirEmpresa(context, ref, emp.nome),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Nota('Frota Gestor $versaoApp  ·  Plataforma de Gestão de Frota  ·  Fortaleza Digital Security'),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------- dados da empresa

class _FormEmpresa extends ConsumerStatefulWidget {
  const _FormEmpresa();

  @override
  ConsumerState<_FormEmpresa> createState() => _FormEmpresaState();
}

class _FormEmpresaState extends ConsumerState<_FormEmpresa> {
  late final Empresa _emp = ref.read(equipeProvider).requireValue.empresa;
  late final _nome = TextEditingController(text: _emp.nome);
  late final _doc = TextEditingController(text: _emp.documento ?? '');
  String? _erro;

  Future<void> _salvar() async {
    if (_nome.text.trim().isEmpty) return setState(() => _erro = 'Escreva o nome da empresa.');
    final navegador = Navigator.of(context);
    final ok = await executar(
      context,
      () => ref.read(equipeProvider.notifier).salvarEmpresa({
        'nome': _nome.text.trim(),
        'documento': _doc.text.trim().isEmpty ? null : _doc.text.trim(),
      }),
      sucesso: 'Dados da empresa salvos.',
    );
    if (ok) navegador.pop();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Dados da empresa'),
    scrollable: true,
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Campo(controle: _nome, rotulo: 'Nome da empresa', maiusculas: TextCapitalization.words),
          const SizedBox(height: 12),
          Campo(controle: _doc, rotulo: 'CNPJ ou CPF (opcional)'),
          if (_erro != null) ...[
            const SizedBox(height: 10),
            Text(_erro!, style: TextStyle(color: context.cores.negativo)),
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

// ------------------------------------------------------------ regras de acerto

/// As perguntas do Meu Frete, respondidas pelo dono para a empresa toda.
class TelaRegras extends ConsumerStatefulWidget {
  const TelaRegras({super.key});

  @override
  ConsumerState<TelaRegras> createState() => _TelaRegrasState();
}

class _TelaRegrasState extends ConsumerState<TelaRegras> {
  late final ConfiguracaoEmpresa _c = ref.read(equipeProvider).requireValue.empresa.configuracao;
  late final _percentual = TextEditingController(text: textoDecimal(_c.percentualComissaoPadrao));
  late bool _sobreBruto = _c.comissaoSobreBrutoPadrao;
  late bool _gastos = _c.gastosDescontamDoLiquido;
  late bool _vale = _c.valeDescontaDoLiquido;
  String? _erro;

  Future<void> _salvar() async {
    final p = lerNumero(_percentual.text);
    if (p < 0 || p > 100) return setState(() => _erro = 'A comissão fica entre 0 e 100%.');
    final navegador = Navigator.of(context);
    final ok = await executar(
      context,
      () => ref.read(equipeProvider.notifier).salvarEmpresa({
        'percentual_comissao_padrao': p,
        'comissao_sobre_bruto_padrao': _sobreBruto,
        'gastos_descontam_do_liquido': _gastos,
        'vale_desconta_do_liquido': _vale,
      }),
      sucesso: 'Regras salvas. Os apps dos motoristas recebem na próxima conexão.',
    );
    if (ok) navegador.pop();
  }

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    Widget pergunta(String texto) => Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 8),
      child: Text(texto, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600)),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Regras de acerto')),
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
                  'Como a empresa acerta com os motoristas. Vale para as contas do painel e do app de cada motorista.',
                  style: TextStyle(fontSize: 15.5, color: cores.textoFraco),
                ),
                pergunta('Comissão padrão do motorista'),
                Campo(
                  controle: _percentual,
                  rotulo: 'Comissão',
                  tipo: TipoCampo.decimal,
                  sufixo: '%',
                  ajuda: 'O motorista pode mudar em cada frete. Fretes já lançados não mudam.',
                ),
                pergunta('A comissão é sobre'),
                EscolhaDupla(
                  valor: _sobreBruto,
                  textoSim: 'Frete + pedágio',
                  textoNao: 'Só o frete',
                  aoMudar: (v) => setState(() => _sobreBruto = v),
                ),
                pergunta('Diesel e gastos da viagem'),
                OpcaoEscolha<bool>(
                  valor: false,
                  escolhido: _gastos,
                  titulo: 'A empresa paga',
                  descricao: 'Não descontam do que o motorista tem para receber.',
                  aoEscolher: (v) => setState(() => _gastos = v),
                ),
                OpcaoEscolha<bool>(
                  valor: true,
                  escolhido: _gastos,
                  titulo: 'Saem do bolso do motorista',
                  descricao: 'Descontam da comissão dele.',
                  aoEscolher: (v) => setState(() => _gastos = v),
                ),
                pergunta('Vale'),
                OpcaoEscolha<bool>(
                  valor: true,
                  escolhido: _vale,
                  titulo: 'Desconta do que ele tem para receber',
                  aoEscolher: (v) => setState(() => _vale = v),
                ),
                OpcaoEscolha<bool>(
                  valor: false,
                  escolhido: _vale,
                  titulo: 'Só para histórico',
                  descricao: 'Não mexe na conta do motorista.',
                  aoEscolher: (v) => setState(() => _vale = v),
                ),
                if (_erro != null) ...[
                  const SizedBox(height: 10),
                  Text(_erro!, style: TextStyle(color: cores.negativo)),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: RodapeBotao(texto: 'Salvar regras', aoTocar: _salvar),
    );
  }
}

// ------------------------------------------------------------------ categorias

class TelaCategorias extends ConsumerWidget {
  const TelaCategorias({super.key});

  Future<void> _editar(BuildContext context, WidgetRef ref, {CategoriaGasto? c}) async {
    final controle = TextEditingController(text: c?.nome ?? '');
    final nome = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(c == null ? 'Nova categoria' : 'Mudar o nome'),
        content: SizedBox(
          width: 380,
          child: Campo(controle: controle, rotulo: 'Nome', autofoco: true, maiusculas: TextCapitalization.sentences),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controle.text.trim()), child: const Text('Salvar')),
        ],
      ),
    );
    if (nome == null || nome.isEmpty || !context.mounted) return;
    await executar(
      context,
      () => ref.read(equipeProvider.notifier).salvarCategoria(id: c?.id, nome: nome),
      sucesso: 'Categoria salva.',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = assistirEquipe(ref);
    return Scaffold(
      appBar: AppBar(title: const Text('Categorias de gasto')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'nova_categoria',
        onPressed: () => _editar(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nova categoria'),
      ),
      body: ListaCentral(
        largura: 620,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Nota(
              'O motorista escolhe a categoria ao lançar um gasto. Desligar uma categoria tira ela da lista '
              'dele, mas os gastos antigos continuam.',
            ),
          ),
          for (final c in e.categorias)
            SwitchListTile(
              title: Text(c.nome, style: TextStyle(color: c.ativa ? null : context.cores.textoFraco)),
              subtitle: Text(c.ativa ? 'Aparece no app' : 'Desligada'),
              value: c.ativa,
              onChanged: (v) => executar(context, () => ref.read(equipeProvider.notifier).ativarCategoria(c.id, v)),
              secondary: IconButton(
                tooltip: 'Mudar o nome',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editar(context, ref, c: c),
              ),
            ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------- gestores

class TelaGestores extends ConsumerWidget {
  const TelaGestores({super.key});

  Future<void> _novo(BuildContext context, WidgetRef ref) async {
    final nome = TextEditingController();
    final email = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Criar acesso de gestor'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'O painel cria uma senha provisória. Você passa para a pessoa e ela entra com o e-mail '
                'e essa senha; no primeiro login ela cria a senha dela.',
              ),
              const SizedBox(height: 14),
              Campo(controle: nome, rotulo: 'Nome do gestor', maiusculas: TextCapitalization.words, autofoco: true),
              const SizedBox(height: 12),
              Campo(controle: email, rotulo: 'E-mail do gestor', tipo: TipoCampo.email),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Criar acesso')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    if (nome.text.trim().length < 2) {
      mostrarMensagem(context, 'Escreva o nome do gestor.');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.text.trim())) {
      mostrarMensagem(context, 'E-mail inválido.');
      return;
    }
    await _gerar(context, ref, email.text.trim(), nome.text.trim());
  }

  /// Cria ou renova o acesso e mostra a senha provisória (só agora).
  Future<void> _gerar(BuildContext context, WidgetRef ref, String email, String nome) async {
    Map<String, Object?>? r;
    await executar(context, () async => r = await ref.read(equipeProvider.notifier).criarAcessoGestor(email, nome));
    final senha = r?['senha_provisoria']?.toString();
    if (senha == null || !context.mounted) return;
    final quem = '${r?['nome'] ?? nome}'.trim();
    final recado =
        'Seu acesso ao painel da frota: entre no app Frota Gestor com o e-mail $email e a senha '
        'provisória $senha. No primeiro login você cria a sua senha.';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Senha provisória'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Passe para ${quem.isEmpty ? email : quem}. Ela aparece só agora.'),
            const SizedBox(height: 16),
            Center(
              child: SelectableText(senha, style: estiloNumero(34, peso: FontWeight.w700).copyWith(letterSpacing: 4)),
            ),
            const SizedBox(height: 16),
            Text('Entra com o e-mail $email e esta senha.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: recado));
              if (ctx.mounted) mostrarMensagem(ctx, 'Recado copiado. Cole no WhatsApp da pessoa.');
            },
            child: const Text('Copiar recado'),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Pronto')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = assistirEquipe(ref);
    final cores = context.cores;
    final perfisPorEmail = {for (final p in e.perfis) p.email.toLowerCase(): p};
    return Scaffold(
      appBar: AppBar(title: const Text('Donos e gestores')),
      floatingActionButton: e.souDono
          ? FloatingActionButton.extended(
              heroTag: 'novo_gestor',
              onPressed: () => _novo(context, ref),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Criar acesso de gestor'),
            )
          : null,
      body: ListaCentral(
        largura: 680,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Nota(
              e.souDono
                  ? 'O gestor vê tudo, aprova motoristas, cadastra caminhões e faz correções. Só o dono muda as regras '
                        'da empresa e libera gestores.'
                  : 'Só o dono libera ou tira gestores.',
            ),
          ),
          for (final a in e.acessos)
            ListTile(
              leading: Icon(
                a.papel == 'dono' ? Icons.workspace_premium_outlined : Icons.manage_accounts_outlined,
                color: a.ativo ? null : cores.textoFraco,
              ),
              title: Text(perfisPorEmail[a.email]?.nome ?? a.email),
              subtitle: Text(
                [
                  a.email,
                  a.papel == 'dono' ? 'dono' : 'gestor',
                  if (!a.ativo) 'sem acesso' else if (perfisPorEmail[a.email] == null) 'ainda sem senha',
                ].join('  ·  '),
              ),
              trailing: e.souDono && a.email != e.eu.email.toLowerCase()
                  ? PopupMenuButton<String>(
                      tooltip: 'Opções',
                      onSelected: (op) async {
                        if (op == 'senha') {
                          await _gerar(context, ref, a.email, perfisPorEmail[a.email]?.nome ?? '');
                          return;
                        }
                        final ok = await confirmar(
                          context,
                          titulo: a.ativo ? 'Tirar o acesso?' : 'Devolver o acesso?',
                          texto: a.ativo
                              ? '${a.email} não consegue mais entrar no painel desta empresa.'
                              : '${a.email} volta a entrar no painel.',
                          botao: a.ativo ? 'Tirar acesso' : 'Devolver',
                          perigo: a.ativo,
                        );
                        if (ok && context.mounted) {
                          await executar(context, () => ref.read(equipeProvider.notifier).ativarAcesso(a.id, !a.ativo));
                        }
                      },
                      itemBuilder: (_) => [
                        if (a.ativo && a.papel == 'gestor')
                          const PopupMenuItem(value: 'senha', child: Text('Gerar senha provisória')),
                        PopupMenuItem(value: 'ativo', child: Text(a.ativo ? 'Tirar acesso' : 'Devolver acesso')),
                      ],
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- aparelhos

class TelaAparelhos extends ConsumerWidget {
  const TelaAparelhos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = assistirEquipe(ref);
    final agora = ref.read(relogioProvider)();
    final nomePorPerfil = {for (final m in e.motoristas) m.perfilId: m.nome};
    final lista = [...e.dispositivos]
      ..sort((a, b) => (b.ultimoEnvio ?? DateTime(2000)).compareTo(a.ultimoEnvio ?? DateTime(2000)));
    return Scaffold(
      appBar: AppBar(title: const Text('Celulares dos motoristas')),
      body: ListaCentral(
        largura: 680,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Nota(
              'Cada celular aparece aqui depois do primeiro envio. Desligue um celular perdido ou trocado: '
              'ele para de mandar dados.',
            ),
          ),
          if (lista.isEmpty)
            const Padding(padding: EdgeInsets.all(20), child: Text('Nenhum celular enviou dados ainda.')),
          for (final d in lista)
            ListTile(
              leading: Icon(d.revogado ? Icons.phonelink_erase : Icons.smartphone),
              title: Text('${nomePorPerfil[d.perfilId] ?? 'Motorista'}  ·  ${d.apelido}'),
              subtitle: Text(
                d.revogado
                    ? 'Desligado em ${dataTexto(d.revogadoEm!.toLocal())}'
                    : 'Último envio ${quandoTexto(d.ultimoEnvio, agora)}',
              ),
              trailing: d.revogado
                  ? null
                  : TextButton(
                      onPressed: () async {
                        final ok = await confirmar(
                          context,
                          titulo: 'Desligar este celular?',
                          texto: 'Ele para de enviar dados para o painel.',
                          botao: 'Desligar',
                          perigo: true,
                        );
                        if (ok && context.mounted) {
                          await executar(
                            context,
                            () => ref.read(equipeProvider.notifier).revogarAparelho(d.id),
                            sucesso: 'Celular desligado.',
                          );
                        }
                      },
                      child: const Text('Desligar'),
                    ),
            ),
        ],
      ),
    );
  }
}
