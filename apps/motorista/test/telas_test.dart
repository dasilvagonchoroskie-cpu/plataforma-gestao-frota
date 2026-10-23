import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motorista/acesso/acesso.dart' show chaveTermosAparelho;
import 'package:motorista/app.dart';
import 'package:motorista/dados/armazenamento.dart';
import 'package:motorista/dados/dados.dart';
import 'package:motorista/telas/casca.dart';
import 'package:visual/visual.dart';

import 'amostra.dart';
import 'apoio.dart';

/// Celular sem dados. [termos]: os termos já foram aceitos ao abrir o app.
Future<ArmazenamentoMemoria> celularNovo({bool termos = true}) async {
  final a = ArmazenamentoMemoria();
  if (termos) await a.gravarEstado(chaveTermosAparelho, versaoTermos);
  return a;
}

Future<ArmazenamentoMemoria> abrir(WidgetTester tester, {ArmazenamentoMemoria? a, ServidorFalso? s}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  final armazenamento = a ?? await celularComAmostra();
  final servidor = s ?? servidorComCadastros();
  servidor.online = false;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      armazenamentoProvider.overrideWithValue(armazenamento),
      servidorProvider.overrideWithValue(servidor),
      sincronizarSozinhoProvider.overrideWithValue(false),
    ],
    child: const AplicativoMotorista(),
  ));
  await tester.pumpAndSettle();
  return armazenamento;
}

void main() {
  testWidgets('celular já aprovado abre direto no Início, mesmo sem internet', (tester) async {
    await abrir(tester);
    expect(find.text('O que você quer ver?'), findsOneWidget);
    expect(find.text('Fretes'), findsOneWidget);
    expect(find.textContaining('Para receber em'), findsOneWidget);
    expect(find.text('Lançando neste caminhão'), findsOneWidget);
    expect(find.textContaining('aguardando internet'), findsOneWidget);
  });

  testWidgets('lançar um vale pelo botão grande', (tester) async {
    final a = await abrir(tester);
    await tester.tap(find.text('Lançar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vale'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '12345');
    await tester.pumpAndSettle();
    expect(find.text('123,45'), findsOneWidget);
    await tester.tap(find.text('Salvar vale'));
    await tester.pumpAndSettle();
    expect(find.text('Vale salvo.'), findsOneWidget);
    final vales = await a.registros('vales');
    expect(vales.map((v) => v['valor_centavos']), containsAll([50000, 12345]));
    expect((await a.fila()).where((i) => i.tabela == 'vales').length, 1);
  });

  testWidgets('frete corrigido pelo gestor não pode ser mudado', (tester) async {
    await abrir(tester);
    await tester.tap(find.text('Fretes'));
    await tester.pumpAndSettle();
    expect(find.text('Corrigido pelo gestor'), findsOneWidget);
    await tester.tap(find.text('Rio Verde (GO)').first);
    await tester.pumpAndSettle();
    expect(find.text('O seu patrão corrigiu este lançamento'), findsOneWidget);
    expect(find.byTooltip('Mudar'), findsNothing);
    expect(find.text('Enviar acerto da viagem'), findsOneWidget);
  });

  testWidgets('trocar de caminhão explica que o que foi lançado fica no antigo', (tester) async {
    final a = await abrir(tester);
    await tester.tap(find.text('Trocar').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Frota 12'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Você vai lançar no caminhão DEF-4567'), findsOneWidget);
    expect(find.textContaining('continua no caminhão RVG2C47'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Trocar'));
    await tester.pumpAndSettle();
    final usos = await a.registros('uso_caminhao');
    expect(usos.length, 2);
    expect(find.textContaining('Agora você está no DEF-4567'), findsOneWidget);
  });

  testWidgets('sem conta: tela de boas-vindas e login por CPF confere o número', (tester) async {
    final s = servidorComCadastros()..sessao = false;
    await abrir(tester, a: await celularNovo(), s: s);
    expect(find.text('Entrar com CPF e senha'), findsOneWidget);
    await tester.tap(find.text('Entrar com CPF e senha'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '12345678900');
    await tester.tap(find.text('Entrar').last);
    await tester.pumpAndSettle();
    expect(find.text('Confira o CPF: tem 11 números.'), findsOneWidget);
  });

  testWidgets('novo frete: a conferência mostra a sua parte na hora', (tester) async {
    await abrir(tester);
    await tester.tap(find.text('Fretes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Novo frete'));
    await tester.pumpAndSettle();
    Future<void> preencher(String rotulo, String texto) async {
      final campo = find.widgetWithText(TextField, rotulo);
      await tester.scrollUntilVisible(campo, 200, scrollable: find.byType(Scrollable).last);
      await tester.enterText(campo, texto);
      await tester.pumpAndSettle();
    }

    await preencher('Origem (de onde saiu)', 'Goiatuba');
    await preencher('Destino (para onde vai)', 'Santos');
    await preencher('Peso na carga', '37000');
    await preencher('Valor da tonelada', '18500');
    await preencher('Adiantamento', '480000');
    await preencher('Saldo', '195000');
    await tester.scrollUntilVisible(find.text('Sua parte (13%)'), 300, scrollable: find.byType(Scrollable).last);
    expect(find.text('R\$ 877,50'), findsOneWidget);
  });

  testWidgets('criar conta: nome, CPF, senha e o e-mail para recuperar a senha', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final s = ServidorFalso()
      ..sessao = false
      ..situacaoFixa = {
        'logado': true,
        'perfil': {'id': 'u-novo', 'nome': 'Novo Motorista', 'papel': 'motorista', 'ativo': true},
        'empresa': null,
        'motorista': null,
        'pedido': null,
      };
    final a = await celularNovo();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        armazenamentoProvider.overrideWithValue(a),
        servidorProvider.overrideWithValue(s),
        sincronizarSozinhoProvider.overrideWithValue(false),
      ],
      child: const AplicativoMotorista(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar minha conta'));
    await tester.pumpAndSettle();
    expect(find.text('Criar conta'), findsOneWidget);
    expect(find.text('Li e aceito os Termos de Uso e a Política de Privacidade.'), findsNothing,
        reason: 'os termos já foram aceitos na abertura do app');

    final campos = find.byType(TextField);
    await tester.enterText(campos.at(0), 'Novo Motorista');
    await tester.enterText(campos.at(1), '12345678900');
    await tester.enterText(campos.at(2), 'senha123');
    await tester.enterText(campos.at(3), 'novo@');
    await tester.tap(find.text('Criar minha conta'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Confira o CPF'), findsOneWidget);
    expect(find.text('Digite o seu e-mail. É com ele que você recupera a senha.'), findsOneWidget);
    expect(s.cadastros, isEmpty);

    await tester.enterText(campos.at(1), '52998224725');
    await tester.enterText(campos.at(3), 'Novo.Motorista@Gmail.com');
    await tester.tap(find.text('Criar minha conta'));
    await tester.pumpAndSettle();
    expect(s.cadastros, ['52998224725']);
    expect(s.termosAceitos, versaoTermos, reason: 'o aceite da abertura vai junto com o cadastro');
    expect(s.emailsCadastrados, ['novo.motorista@gmail.com']);
    expect(find.textContaining('Mandamos um link para novo.motorista@gmail.com'), findsOneWidget);
    expect(find.text('Código de entrada'), findsOneWidget);
  });

  testWidgets('criar conta exige o e-mail (para recuperar a senha sem o patrão)', (tester) async {
    final s = ServidorFalso()..sessao = false;
    await abrir(tester, a: await celularNovo(), s: s);
    s.online = true;
    await tester.tap(find.text('Criar minha conta'));
    await tester.pumpAndSettle();
    final campos = find.byType(TextField);
    await tester.enterText(campos.at(0), 'Sem Email');
    await tester.enterText(campos.at(1), '52998224725');
    await tester.enterText(campos.at(2), 'senha123');
    await tester.tap(find.text('Criar minha conta'));
    await tester.pumpAndSettle();
    expect(s.cadastros, isEmpty);
    expect(find.text('Digite o seu e-mail. É com ele que você recupera a senha.'), findsOneWidget);
  });

  testWidgets('conta antiga sem e-mail: pede o e-mail antes de continuar', (tester) async {
    final s = servidorComCadastros()..emailConfirmadoNaNuvem = null;
    await abrir(tester, s: s);
    expect(find.text('Cadastre o seu e-mail'), findsOneWidget);
    expect(find.text('O que você quer ver?'), findsNothing);
    s.online = true;
    await tester.enterText(find.byType(TextField), 'Joao@Gmail.com');
    await tester.tap(find.text('Mandar o link de confirmação'));
    await tester.pumpAndSettle();
    expect(s.emailsCadastrados, ['joao@gmail.com']);
    expect(find.text('O que você quer ver?'), findsOneWidget);
    expect(find.text('Confirme o seu e-mail'), findsOneWidget, reason: 'o Início lembra de confirmar');
  });

  testWidgets('sem internet: o e-mail fica para depois', (tester) async {
    final s = servidorComCadastros()..emailConfirmadoNaNuvem = null;
    await abrir(tester, s: s);
    await tester.enterText(find.byType(TextField), 'joao@gmail.com');
    await tester.tap(find.text('Mandar o link de confirmação'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fazer depois (sem internet agora)'));
    await tester.pumpAndSettle();
    expect(find.text('O que você quer ver?'), findsOneWidget);
  });

  testWidgets('aviso no Resumo até confirmar: mandar o link de novo', (tester) async {
    final s = servidorComCadastros()
      ..emailConfirmadoNaNuvem = null
      ..emailEsperandoNaNuvem = 'joao@gmail.com';
    await abrir(tester, s: s);
    expect(find.text('Confirme o seu e-mail'), findsOneWidget);
    s.online = true;
    await tester.tap(find.text('Mandar de novo'));
    await tester.pumpAndSettle();
    expect(s.emailsCadastrados, ['joao@gmail.com']);
    await tester.tap(find.text('Já confirmei'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ainda não aparece confirmado'), findsOneWidget);
  });

  Future<ServidorFalso> abrirSemDados(WidgetTester tester, Map<String, Object?> situacao, {bool termos = true}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final s = ServidorFalso()..situacaoFixa = situacao;
    final a = await celularNovo(termos: termos);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        armazenamentoProvider.overrideWithValue(a),
        servidorProvider.overrideWithValue(s),
        sincronizarSozinhoProvider.overrideWithValue(false),
      ],
      child: const AplicativoMotorista(),
    ));
    await tester.pumpAndSettle();
    return s;
  }

  Map<String, Object?> semEmpresa({bool termos = true}) => {
        'logado': true,
        'perfil': {'id': 'u-novo', 'nome': 'Novo Motorista', 'papel': 'motorista', 'ativo': true},
        'empresa': null,
        'motorista': null,
        'pedido': null,
        'termos': {'versao': versaoTermos, 'aceito': termos},
      };

  testWidgets('primeira abertura: termos antes de tudo; o aceite vai para a conta', (tester) async {
    final s = await abrirSemDados(tester, semEmpresa(termos: false), termos: false);
    expect(find.text('Termos de Uso e Privacidade'), findsOneWidget);
    expect(find.text('Código de entrada'), findsNothing, reason: 'nada abre antes do aceite');
    await tester.ensureVisible(find.text('Não aceito'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Não aceito'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('Sem aceitar'));
    expect(find.textContaining('Sem aceitar, não dá para usar.'), findsOneWidget);
    await tester.tap(find.text('Aceitar e continuar'));
    await tester.pumpAndSettle();
    expect(s.termosAceitos, isNull, reason: 'precisa marcar que leu');
    await tester.tap(find.text('Li e aceito os Termos de Uso e a Política de Privacidade.'));
    await tester.tap(find.text('Aceitar e continuar'));
    await tester.pumpAndSettle();
    expect(s.termosAceitos, versaoTermos, reason: 'com a conta aberta, o aceite também vai para a nuvem');
    expect(find.text('Código de entrada'), findsOneWidget);
  });

  testWidgets('sair da conta não pede os termos de novo neste celular', (tester) async {
    final s = await abrirSemDados(tester, semEmpresa());
    s.sessao = false;
    await tester.tap(find.text('Sair desta conta'));
    await tester.pumpAndSettle();
    expect(find.text('Entrar com CPF e senha'), findsOneWidget);
    expect(find.text('Termos de Uso e Privacidade'), findsNothing);
  });

  testWidgets('os termos abrem para ler', (tester) async {
    await abrirSemDados(tester, semEmpresa(termos: false), termos: false);
    await tester.tap(find.text('Política de Privacidade'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Lei Geral de Proteção de Dados Pessoais'), findsWidgets);
  });

  testWidgets('esqueci a senha: o link vai para o e-mail confirmado do motorista', (tester) async {
    final s = await abrirSemDados(tester, semEmpresa());
    s.sessao = false;
    await tester.tap(find.text('Sair desta conta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Esqueci a senha'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '123');
    await tester.tap(find.text('Mandar o link'));
    await tester.pumpAndSettle();
    expect(find.text('Confira o CPF: tem 11 números.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '52998224725');
    await tester.tap(find.text('Mandar o link'));
    await tester.pumpAndSettle();
    expect(s.linksPedidos, ['52998224725']);
    expect(find.textContaining('mandamos um link para ele'), findsOneWidget);
    expect(find.textContaining('Use só o e-mail mais novo'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('Redefinir o acesso'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Redefinir o acesso'), findsOneWidget, reason: 'sem e-mail, o patrão ajuda');
  });

  testWidgets('configurações: cadastrar o e-mail para recuperar a senha', (tester) async {
    final s = servidorComCadastros()
      ..emailConfirmadoNaNuvem = null
      ..emailEsperandoNaNuvem = 'antigo@gmail.com';
    await abrir(tester, s: s);
    s.online = true;
    await tester.tap(find.byTooltip('Configurações'));
    await tester.pumpAndSettle();
    expect(find.text('Não cadastrado'), findsOneWidget);
    await tester.tap(find.text('E-mail para recuperar a senha'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum e-mail confirmado ainda.'), findsOneWidget);
    expect(find.text('Falta confirmar'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'joao@');
    await tester.tap(find.text('Mandar o link de confirmação'));
    await tester.pumpAndSettle();
    expect(find.text('Confira o e-mail.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Joao@Gmail.com');
    await tester.tap(find.text('Mandar o link de confirmação'));
    await tester.pumpAndSettle();
    expect(s.emailsCadastrados, ['joao@gmail.com']);
    expect(find.textContaining('Mandamos um link para joao@gmail.com'), findsOneWidget);
  });

  testWidgets('empresa com o acesso encerrado: o app fecha e mostra o motivo', (tester) async {
    final armazenamento = await celularComAmostra();
    final situacao = situacaoDe(motoristaA);
    await armazenamento.gravarEstado('situacao', jsonEncode({
      ...situacao,
      'empresa': {...situacao['empresa']! as Map, 'bloqueada': true, 'motivo_bloqueio': 'O período de teste terminou.'},
    }));
    final s = servidorComCadastros()
      ..situacaoFixa = {
        ...situacao,
        'empresa': {...situacao['empresa']! as Map, 'bloqueada': true, 'motivo_bloqueio': 'O período de teste terminou.'},
      };
    await abrir(tester, a: armazenamento, s: s);
    expect(find.text('Acesso encerrado'), findsOneWidget);
    expect(find.text('Motivo: O período de teste terminou.'), findsOneWidget);
    expect(find.text('O que você quer ver?'), findsNothing);
  });

  testWidgets('excluir a minha conta pede para digitar EXCLUIR', (tester) async {
    final s = await abrirSemDados(tester, semEmpresa());
    await tester.tap(find.text('Excluir minha conta'));
    await tester.pumpAndSettle();
    final botao = find.widgetWithText(FilledButton, 'Excluir a conta');
    expect(tester.widget<FilledButton>(botao).onPressed, isNull);
    await tester.enterText(find.byType(TextField).last, 'excluir');
    await tester.pumpAndSettle();
    await tester.tap(botao);
    await tester.pumpAndSettle();
    expect(s.contaExcluida, isTrue);
    expect(find.text('Entrar com CPF e senha'), findsOneWidget);
  });
}
