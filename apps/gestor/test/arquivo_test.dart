// PDF com todos os dados antes de qualquer exclusão (regra aprovada pelo dono
// em 23/10/2026): na exclusão pelo painel, nos avisos do painel e a qualquer
// hora em Configurações.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor/dados/equipe.dart';
import 'package:gestor/servidor/servidor.dart';
import 'package:nucleo/nucleo.dart';

import 'apoio.dart';
import 'paradas_test.dart' show servidorComParadas;

void main() {
  test('o arquivo da empresa leva caminhões e cada motorista com todo o histórico', () async {
    final s = servidorComParadas();
    final agora = DateTime.now();
    final e = Equipe.montar(situacao: await s.situacao(), tabelas: await s.carregar(), pedidos: const [], agora: agora);
    final d = e.arquivoDeDados(agora: agora);
    expect(d.daEmpresaToda, isTrue);
    expect(d.caminhoes, hasLength(3));
    expect(d.motoristas.map((m) => m.nome), containsAll(['João Batista', 'Pedro Henrique', 'Carlos Souza']),
        reason: 'até o desligado vai junto');
    final joao = d.motoristas.firstWhere((m) => m.nome == 'João Batista');
    expect(joao.cpf, '111.444.777-35');
    expect(joao.relatorio.fretes, hasLength(2), reason: 'todo o histórico, não só o mês');
    expect(joao.paradas!.resumo.paradas, hasLength(5));
    expect(d.motoristas.firstWhere((m) => m.nome == 'Carlos Souza').paradas, isNull);

    final so = e.arquivoDeDados(motoristaId: pedro, agora: agora);
    expect(so.daEmpresaToda, isFalse);
    expect(so.motoristas.single.nome, 'Pedro Henrique');
    expect(so.caminhoes, isEmpty);
  });

  testWidgets('desistir no passo do PDF não exclui nada', (tester) async {
    final s = servidorComAmostra();
    final arquivos = guardarArquivos();
    await abrirApp(tester, s);
    await tester.tap(find.text('Motoristas').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carlos Souza').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mais ações'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir motorista e dados'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(arquivos, isEmpty);
    expect(find.text('Digite EXCLUIR'), findsNothing);
    expect(s.chamadas.where((c) => c.startsWith('excluir motorista')), isEmpty);
  });

  testWidgets('motorista excluiu a conta: o painel avisa e baixa o PDF dele', (tester) async {
    final s = servidorComAmostra();
    final pedido = DateTime.now().subtract(const Duration(days: 3));
    // Desde 23/10/2026 o login sai na hora; a data fica no cadastro dele.
    pedroExcluiuAConta(s, pedido);
    final arquivos = guardarArquivos();
    await abrirApp(tester, s);
    expect(find.text('Pedro excluiu a conta'), findsOneWidget);
    expect(find.textContaining('ficam até ${dataTexto(pedido.add(prazoExclusaoMotorista))}'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Baixar PDF'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(arquivos.single.nome, startsWith('Frota_arquivo_Pedro_'));
    expect(find.text('PDF com todos os dados gerado. Guarde o arquivo.'), findsOneWidget);
  });

  testWidgets('quem excluiu a conta não tem login para religar nem redefinir', (tester) async {
    final s = servidorComAmostra();
    pedroExcluiuAConta(s, DateTime.now().subtract(const Duration(days: 1)));
    await abrirApp(tester, s);
    await tester.tap(find.text('Motoristas').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Excluiu a conta em'), findsOneWidget);
    await tester.ensureVisible(find.text('Pedro Henrique').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pedro Henrique').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mais ações'));
    await tester.pumpAndSettle();
    expect(find.text('Excluir motorista e dados'), findsOneWidget);
    expect(find.text('Redefinir o acesso'), findsNothing);
    expect(find.text('Religar na empresa'), findsNothing);
    expect(find.text('Gerar código para voltar'), findsOneWidget);
  });

  testWidgets('acesso da empresa acabando: o painel avisa e baixa o PDF com tudo', (tester) async {
    final fim = DateTime.now().add(const Duration(days: 3));
    final s = servidorComAmostra();
    s.empresa['acesso_ate'] = iso(fim);
    s.empresaExtra = {'excluir_em': iso(fim.add(const Duration(days: 30)))};
    final arquivos = guardarArquivos();
    await abrirApp(tester, s);
    expect(find.text('O acesso da empresa termina em ${dataTexto(fim)}'), findsOneWidget);
    expect(find.textContaining('guardados até ${dataTexto(fim.add(const Duration(days: 30)))}'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Baixar PDF'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(arquivos.single.nome, startsWith('Frota_arquivo_Transportes_Goiatuba_'));
  });

  testWidgets('o dono baixa todos os dados em Configurações e, para excluir a empresa, o PDF vem antes', (tester) async {
    final s = servidorComAmostra();
    final arquivos = guardarArquivos();
    await abrirApp(tester, s);
    await tester.tap(find.text('Configurações').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Baixar todos os dados da empresa (PDF)'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Baixar todos os dados da empresa (PDF)'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(arquivos, hasLength(1));

    await tester.ensureVisible(find.text('Excluir a conta da empresa e todos os dados'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir a conta da empresa e todos os dados'));
    await tester.pumpAndSettle();
    expect(find.text('Primeiro, o PDF com todos os dados'), findsOneWidget);
    await gerarPdfNaTela(tester);
    expect(arquivos, hasLength(2));
    expect(find.text('Excluir a empresa e todos os dados?'), findsOneWidget);
  });
}

/// Pedro excluiu a conta: desde 23/10/2026 o login sai na hora e a data fica
/// no cadastro dele, que fica sem login.
void pedroExcluiuAConta(ServidorFalso s, DateTime quando) {
  s.t(Fontes.motoristas).firstWhere((m) => m['perfil_id'] == 'u-pedro')
    ..['exclusao_pedida_em'] = iso(quando)
    ..['perfil_id'] = null
    ..['ativo'] = false;
  s.t(Fontes.perfis).removeWhere((p) => p['id'] == 'u-pedro');
}
