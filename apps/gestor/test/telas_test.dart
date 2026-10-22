import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor/dados/link_email.dart';
import 'package:gestor/servidor/servidor.dart';
import 'package:gestor/telas/lancamentos/detalhe_lancamento.dart';

import 'package:nucleo/nucleo.dart' show mensagemSenha;
import 'package:visual/visual.dart' show versaoTermos;

import 'apoio.dart';

void main() {
  testWidgets('entrar com e-mail e senha abre o painel da empresa', (tester) async {
    final s = servidorComAmostra()..sessao = false;
    await abrirApp(tester, s);
    expect(find.text('Esqueci a senha'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'dono@teste.com');
    await tester.enterText(find.byType(TextField).at(1), 'errada');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'segredo1');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Faturamento'), findsWidgets);
    expect(find.text('Transportes Goiatuba'), findsWidgets);
    expect(find.byType(NavigationRail), findsOneWidget, reason: 'no computador o menu fica do lado');
  });

  testWidgets('no celular as partes ficam nas abas de baixo', (tester) async {
    await abrirApp(tester, servidorComAmostra(), tela: celular, densidade: 2.75);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Faturamento'), findsWidgets);
  });

  testWidgets('aprovar o motorista que pediu para entrar', (tester) async {
    final s = servidorComAmostra();
    await abrirApp(tester, s);
    expect(find.text('1 motorista quer entrar'), findsOneWidget);
    await tester.tap(find.text('1 motorista quer entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Marcos Vinícius'), findsOneWidget);
    expect(find.textContaining('529.982.247-25'), findsOneWidget, reason: 'o gestor confere o CPF antes de aprovar');
    await tester.tap(find.text('Aprovar'));
    await tester.pumpAndSettle();

    expect(s.chamadas, contains('decidir ped-1 true'));
    expect(find.text('Marcos Vinícius entrou na empresa.'), findsOneWidget);
    expect(find.text('Pedidos para entrar'), findsNothing);
    expect(find.text('Marcos Vinícius'), findsOneWidget, reason: 'agora aparece na lista da empresa');
  });

  testWidgets('corrigir o saldo de um frete com motivo (o original fica)', (tester) async {
    final s = servidorComAmostra();
    await abrirApp(tester, s);
    await tester.tap(find.text('Lançamentos'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Paranaguá (PR)  –  Rio Verde (GO)'));
    await tester.pumpAndSettle();

    final lista = find.descendant(of: find.byType(TelaDetalheLancamento), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('Saldo'), 200, scrollable: lista);
    await tester.tap(find.text('Saldo'));
    await tester.pumpAndSettle();
    expect(find.text('Corrigir saldo'), findsOneWidget);
    final campos = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
    await tester.enterText(campos.at(0), '150000');
    await tester.tap(find.text('Salvar correção'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Escreva o motivo'), findsOneWidget, reason: 'sem motivo não salva');

    await tester.enterText(campos.at(1), 'Conferido no extrato');
    await tester.tap(find.text('Salvar correção'));
    await tester.pumpAndSettle();

    final ajuste = s.t('ajustes_gestor').single;
    expect(ajuste['campo'], 'saldo_centavos');
    expect(ajuste['valor_novo'], 150000);
    expect(ajuste['valor_novo'], isA<int>());
    expect(ajuste['motivo'], 'Conferido no extrato');
    expect(ajuste['autor_id'], euDono);
    await tester.scrollUntilVisible(find.textContaining('"Conferido no extrato"'), 200, scrollable: lista);
    expect(find.textContaining('"Conferido no extrato"'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Corrigido pela gestão'), -200, scrollable: lista);
    expect(find.text('Corrigido pela gestão'), findsOneWidget);
  });

  testWidgets('ver o resumo como o motorista vê no app dele', (tester) async {
    await abrirApp(tester, servidorComAmostra());
    await tester.tap(find.text('Motoristas').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('João Batista'));
    await tester.pumpAndSettle();
    expect(find.text('Você tem para receber'), findsOneWidget);
    expect(find.text('Conta do caminhão'), findsOneWidget);
    expect(find.textContaining('mesma tela que João vê'), findsOneWidget);
  });

  testWidgets('trocar o caminhão de um motorista pelo painel', (tester) async {
    final s = servidorComAmostra();
    await abrirApp(tester, s);
    await tester.tap(find.text('Motoristas').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pedro Henrique'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mais ações'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trocar o caminhão dele'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Frota 07  ·  Scania R450'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trocar'));
    await tester.pumpAndSettle();
    expect(s.chamadas, contains('caminhao $pedro $cam1'));
    expect(find.text('Caminhão trocado.'), findsOneWidget);
  });

  testWidgets('cadastrar caminhão: placa errada e placa repetida não passam', (tester) async {
    final s = servidorComAmostra();
    await abrirApp(tester, s);
    await tester.tap(find.text('Caminhões').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Novo caminhão'));
    await tester.pumpAndSettle();
    final campos = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));

    await tester.enterText(campos.at(0), 'AB12');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Placa inválida'), findsOneWidget);

    await tester.enterText(campos.at(0), 'def4567');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Já existe um caminhão'), findsOneWidget);

    await tester.enterText(campos.at(0), 'GHI2J34');
    await tester.enterText(campos.at(1), '15');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    final novo = s.t('caminhoes').last;
    expect(novo['placa'], 'GHI2J34');
    expect(novo['numero_frota'], '15');
    expect(novo['confirmado'], true);
    expect(novo['empresa_id'], empresaId);
  });

  testWidgets('gestor vê as regras mas só o dono muda', (tester) async {
    await abrirApp(tester, servidorComAmostra(usuario: euGestor));
    await tester.tap(find.text('Configurações'));
    await tester.pumpAndSettle();
    expect(find.text('Só o dono muda os dados e as regras da empresa.'), findsOneWidget);
    await tester.tap(find.text('Donos e gestores'));
    await tester.pumpAndSettle();
    expect(find.text('Liberar gestor'), findsNothing);
  });

  testWidgets('dono cria o acesso de um gestor com senha provisória', (tester) async {
    final s = servidorComAmostra();
    await abrirApp(tester, s);
    await tester.tap(find.text('Configurações'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Donos e gestores'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar acesso de gestor'));
    await tester.pumpAndSettle();
    final campos = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
    await tester.enterText(campos.at(0), 'Nova Gestora');
    await tester.enterText(campos.at(1), 'Nova.Gestora@Teste.com');
    await tester.tap(find.text('Criar acesso'));
    await tester.pumpAndSettle();
    expect(s.chamadas, contains('acesso gestor nova.gestora@teste.com'));
    expect(find.text('Senha provisória'), findsOneWidget);
    expect(find.text('H4QZ8WMP'), findsOneWidget);
    await tester.tap(find.text('Pronto'));
    await tester.pumpAndSettle();
    expect(find.text('Nova Gestora'), findsOneWidget);
  });

  testWidgets('primeiro login com senha provisória: cria a senha antes de abrir o painel', (tester) async {
    final s = servidorComAmostra(usuario: euGestor)..trocarSenha = true;
    await abrirApp(tester, s);
    expect(find.text('Crie a sua senha'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'minhasenha1');
    await tester.tap(find.text('Salvar senha'));
    await tester.pumpAndSettle();
    expect(s.chamadas, contains('senha'));
    expect(find.text('Faturamento'), findsWidgets);
  });

  testWidgets('tela de entrar não pede cadastro por e-mail', (tester) async {
    await abrirApp(tester, servidorComAmostra()..sessao = false);
    expect(find.text('Criar minha conta'), findsNothing);
    expect(find.textContaining('senha provisória'), findsOneWidget);
  });

  testWidgets('sem internet ao abrir: mostra o aviso e deixa tentar de novo', (tester) async {
    final s = servidorComAmostra()..online = false;
    await abrirApp(tester, s);
    expect(find.text('Não deu para abrir'), findsOneWidget);
    expect(find.text(erroSemInternet.mensagem), findsOneWidget);
    s.online = true;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();
    expect(find.text('Faturamento'), findsWidgets);
  });

  testWidgets('cadastrar motorista: o painel gera um código só dele', (tester) async {
    final s = servidorComAmostra();
    await abrirApp(tester, s);
    await tester.tap(find.text('Motoristas').first);
    await tester.pumpAndSettle();
    expect(find.text('Código da empresa'), findsNothing, reason: 'não existe mais código igual para todos');
    await tester.tap(find.text('Cadastrar motorista'));
    await tester.pumpAndSettle();
    final campos = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
    await tester.enterText(campos.at(0), 'Antônio Pereira');
    await tester.enterText(campos.at(1), '12345678900');
    await tester.tap(find.text('Gerar código'));
    await tester.pumpAndSettle();
    expect(find.text('Confira o CPF: tem 11 números.'), findsOneWidget);
    await tester.enterText(campos.at(1), '12345678909');
    await tester.tap(find.text('Gerar código'));
    await tester.pumpAndSettle();
    expect(s.chamadas, contains('convite Antônio Pereira 12345678909'));
    expect(find.text('K7M2QX'), findsOneWidget);
    await tester.tap(find.text('Pronto'));
    await tester.pumpAndSettle();
    expect(find.text('Códigos esperando o motorista (1)'), findsOneWidget);
    expect(find.textContaining('Código K7M2QX'), findsOneWidget);
  });

  testWidgets('excluir motorista e dados pede para digitar EXCLUIR', (tester) async {
    final s = servidorComAmostra();
    await abrirApp(tester, s);
    await tester.tap(find.text('Motoristas').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carlos Souza').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mais ações'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir motorista e dados'));
    await tester.pumpAndSettle();
    await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), 'EXCLUIR');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pumpAndSettle();
    expect(s.chamadas, contains('excluir motorista $carlos'));
    expect(find.text('Motorista e dados excluídos.'), findsOneWidget);
  });

  testWidgets('primeira abertura: aceitar os termos antes de qualquer tela', (tester) async {
    final s = servidorComAmostra()..sessao = false;
    await abrirApp(tester, s, termosAceitosNoAparelho: false);
    expect(find.text('Termos de Uso e Privacidade'), findsOneWidget);
    expect(find.text('Esqueci a senha'), findsNothing, reason: 'nada abre antes do aceite');
    await tester.ensureVisible(find.text('Não aceito'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Não aceito'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('Sem aceitar'));
    expect(find.textContaining('Sem aceitar, não dá para usar.'), findsOneWidget);
    await tester.tap(find.text('Aceitar e continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Esqueci a senha'), findsNothing, reason: 'sem marcar a caixa não passa');
    await tester.tap(find.text('Li e aceito os Termos de Uso e a Política de Privacidade.'));
    await tester.tap(find.text('Aceitar e continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Esqueci a senha'), findsOneWidget);
  });

  testWidgets('versão nova dos termos: o aceite da abertura vai para a conta sem pedir de novo', (tester) async {
    final s = servidorComAmostra()
      ..situacaoExtra = {
        'termos': {'versao': '2026-10-17', 'aceito': false},
      };
    await abrirApp(tester, s, termosAceitosNoAparelho: false);
    await tester.tap(find.text('Li e aceito os Termos de Uso e a Política de Privacidade.'));
    await tester.tap(find.text('Aceitar e continuar'));
    await tester.pumpAndSettle();
    expect(s.termosAceitos, versaoTermos);
    expect(find.text('Faturamento'), findsWidgets);
    expect(s.chamadas, contains('acesso gestor'), reason: 'o acesso fica registrado (Marco Civil)');
  });

  testWidgets('empresa com o acesso encerrado: não abre o painel; o dono pode excluir tudo', (tester) async {
    final s = servidorComAmostra()
      ..empresaExtra = {'bloqueada': true, 'motivo_bloqueio': 'O período de teste terminou.', 'excluir_em': '2026-12-01T12:00:00Z'};
    await abrirApp(tester, s);
    expect(find.text('Acesso encerrado'), findsOneWidget);
    expect(find.text('Motivo: O período de teste terminou.'), findsOneWidget);
    expect(find.text('Faturamento'), findsNothing);
    await tester.tap(find.text('Excluir a conta da empresa e todos os dados'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)),
      'transportes goiatuba',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir tudo'));
    await tester.pumpAndSettle();
    expect(s.empresaExcluida, 'Transportes Goiatuba');
    expect(find.text('Esqueci a senha'), findsOneWidget, reason: 'volta para a tela de entrar');
  });

  testWidgets('esqueci a senha: o link para criar a senha nova vai para o e-mail', (tester) async {
    final s = servidorComAmostra()..sessao = false;
    await abrirApp(tester, s);
    await tester.tap(find.text('Esqueci a senha'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'dono@');
    await tester.tap(find.text('Mandar o link'));
    await tester.pumpAndSettle();
    expect(find.text('Confira o e-mail.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Dono@Teste.com');
    await tester.tap(find.text('Mandar o link'));
    await tester.pumpAndSettle();
    expect(s.linksPedidos, ['dono@teste.com']);
    expect(find.text('Se este e-mail tiver conta, mandamos um link para ele.'), findsOneWidget);
    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('Esqueci a senha'), findsOneWidget);
  });

  testWidgets('link do e-mail: cria a senha nova e encerra as outras sessões', (tester) async {
    final s = servidorComAmostra()
      ..sessao = false
      ..linksValidos.add('abc123def456');
    await abrirApp(tester, s, link: const LinkDoEmail('abc123def456', TipoLink.senha));
    expect(find.text('Crie a senha nova'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'semnumero');
    await tester.tap(find.text('Salvar a senha nova'));
    await tester.pumpAndSettle();
    expect(find.text(mensagemSenha), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'novasenha9');
    await tester.tap(find.text('Salvar a senha nova'));
    await tester.pumpAndSettle();
    expect(find.text('Senha nova criada'), findsOneWidget);
    expect(s.chamadas, containsAllInOrder(['link senha', 'senha', 'sair']));
    expect(s.saiuDeTodos, isTrue);
    await tester.tap(find.text('Ir para a tela de entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Esqueci a senha'), findsOneWidget);
  });

  testWidgets('link do e-mail vencido ou já usado: avisa e leva para entrar', (tester) async {
    final s = servidorComAmostra()..sessao = false;
    await abrirApp(tester, s, link: const LinkDoEmail('vencido12345', TipoLink.senha));
    expect(find.text('Este link não vale mais'), findsOneWidget);
    await tester.tap(find.text('Ir para a tela de entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Esqueci a senha'), findsOneWidget);
  });

  testWidgets('link do e-mail do motorista: confirma o e-mail e sai', (tester) async {
    final s = servidorComAmostra()
      ..sessao = false
      ..linksValidos.add('confirma12345');
    await abrirApp(tester, s, link: const LinkDoEmail('confirma12345', TipoLink.email));
    expect(find.text('E-mail confirmado'), findsOneWidget);
    expect(s.chamadas, containsAllInOrder(['link email', 'sair']));
    expect(s.sessao, isFalse);
  });

  test('o painel só reconhece links de e-mail bem formados', () {
    final senha = LinkDoEmail.doEndereco(Uri.parse('https://x.io/p/?token_hash=abc123def456&type=recovery'));
    expect(senha?.tipo, TipoLink.senha);
    final email = LinkDoEmail.doEndereco(Uri.parse('https://x.io/p/?token_hash=abc123def456&type=email_change'));
    expect(email?.tipo, TipoLink.email);
    expect(LinkDoEmail.doEndereco(Uri.parse('https://x.io/p/?token_hash=abc123def456&type=signup')), isNull);
    expect(LinkDoEmail.doEndereco(Uri.parse('https://x.io/p/?token_hash=<script>&type=recovery')), isNull);
    expect(LinkDoEmail.doEndereco(Uri.parse('https://x.io/p/')), isNull);
  });
}
