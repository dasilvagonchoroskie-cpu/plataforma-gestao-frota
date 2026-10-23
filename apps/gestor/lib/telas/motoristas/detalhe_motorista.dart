import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/arquivo_dados.dart';
import '../../componentes/comuns.dart';
import '../../componentes/itens.dart';
import '../../dados/equipe.dart';
import '../../dados/modelos.dart';
import '../../dados/provedores.dart';
import '../../relatorio/compartilhar.dart';
import '../paradas/tela_paradas.dart';
import 'tela_acerto.dart';
import 'tela_motoristas.dart' show mostrarConvite;

/// Um motorista: o resumo como ele vê no app, os lançamentos e o cadastro.
class TelaDetalheMotorista extends ConsumerWidget {
  const TelaDetalheMotorista({super.key, required this.motoristaId, this.abaInicial = 0});

  final String motoristaId;
  final int abaInicial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = assistirEquipe(ref);
    final m = e.motorista(motoristaId);
    if (m == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EstadoVazio(
          icone: Icons.person_off_outlined,
          titulo: 'Motorista não encontrado',
          texto: 'Atualize a tela.',
        ),
      );
    }
    final escolha = ref.watch(periodoProvider);
    final periodo = escolha.periodoOuMes;
    final dados = e.relatorio(periodo, motoristaId: m.id);
    final tudo = e.recorte(motoristaId: m.id);
    // Baú e Sider: Viagens no lugar de Fretes e a aba dos acertos.
    final porViagem = e.porViagem(m.id);
    // Paradas: só quando a empresa usa o registro.
    final comParadas = e.paradasAtivas;

    return DefaultTabController(
      length: 6 + (porViagem ? 1 : 0) + (comParadas ? 1 : 0),
      initialIndex: abaInicial,
      child: Scaffold(
        appBar: AppBar(
          title: Text(m.nome),
          actions: [
            const BotaoAtualizar(),
            _MenuMotorista(motorista: m),
            const SizedBox(width: 4),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              const Tab(text: 'Como ele vê'),
              Tab(text: porViagem ? 'Viagens' : 'Fretes'),
              const Tab(text: 'Diesel'),
              const Tab(text: 'Gastos'),
              const Tab(text: 'Vales'),
              if (porViagem) const Tab(text: 'Acertos'),
              if (comParadas) const Tab(text: 'Paradas'),
              const Tab(text: 'Cadastro'),
            ],
          ),
        ),
        body: Column(
          children: [
            const SizedBox(height: 8),
            const Centro(largura: 900, child: FaixaPeriodo()),
            if (!m.ativo)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Aviso(
                  icone: Icons.block,
                  titulo: m.desligadoEm == null
                      ? 'Saiu da empresa'
                      : 'Saiu da empresa em ${dataTexto(m.desligadoEm!.toLocal())}',
                  texto: 'Aqui fica o registro dele: nome, CPF e o que já mandou. O login dele ficou livre. '
                      'Se ele voltar, use "Gerar código para voltar" (ele começa um cadastro novo).',
                ),
              ),
            if (m.ativo && m.modalidade == null && e.variasModalidades)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: InkWell(
                  onTap: () => escolherModalidade(context, ref, m),
                  child: Aviso(
                    icone: Icons.alt_route,
                    titulo: 'Falta a modalidade',
                    texto: '${m.primeiroNome} ainda não escolheu no app. Toque aqui para definir agora.',
                  ),
                ),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  ListaCentral(
                    largura: 760,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Nota('É a mesma tela que ${m.primeiroNome} vê no app dele, com as mesmas contas.'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonalIcon(
                              onPressed: () => executar(context, () => compartilharPdf(dados)),
                              icon: const Icon(Icons.picture_as_pdf_outlined),
                              label: const Text('PDF'),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                        child: porViagem
                            ? CorpoResumoViagens(
                                dados: dados,
                                todasAbastecidas: tudo.abastecimentos,
                                descricao: escolha.descricao,
                                empresaNome: e.empresa.nome,
                                acertos: e.acertosDe(m.id),
                                aoAbrirAcerto: (a) => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => TelaAcertoFechado(acertoId: a.id)),
                                ),
                                textoVazio:
                                    '${m.primeiroNome} não lançou nada neste período. Quando ele lançar no app, '
                                    'aparece aqui na próxima vez que o celular dele tiver internet.',
                              )
                            : CorpoResumo(
                                dados: dados,
                                todasAbastecidas: tudo.abastecimentos,
                                descricao: escolha.descricao,
                                empresaNome: e.empresa.nome,
                                percentualPadrao: e.empresa.configuracao.percentualComissaoPadrao,
                                textoVazio:
                                    '${m.primeiroNome} não lançou nada neste período. Quando ele lançar no app, '
                                    'aparece aqui na próxima vez que o celular dele tiver internet.',
                              ),
                      ),
                    ],
                  ),
                  ListaCentral(
                    largura: 900,
                    children: [
                      if (porViagem)
                        ListaPorMes<Viagem>(
                          itens: dados.viagens,
                          data: (v) => v.engateEm,
                          valor: (v) => v.entregasQuantidade,
                          resumo: (l) =>
                              plural(l.fold<int>(0, (s, v) => s + v.entregasQuantidade), 'entrega', 'entregas'),
                          item: (v) => ItemViagem(viagem: v, equipe: e),
                          vazio: 'Nenhuma viagem neste período.',
                        )
                      else
                        ListaPorMes<Frete>(
                          itens: dados.fretes,
                          data: (f) => f.dataCarga,
                          valor: (f) => f.freteRealCentavos,
                          item: (f) => ItemFrete(frete: f, equipe: e),
                          vazio: 'Nenhum frete neste período.',
                        ),
                    ],
                  ),
                  ListaCentral(
                    largura: 900,
                    children: [
                      ListaPorMes<Abastecimento>(
                        itens: tudo.abastecimentos.where((a) => periodo.contem(a.data)).toList(),
                        data: (a) => a.data,
                        valor: (a) => a.valorCentavos,
                        item: (a) => ItemAbastecimento(abastecimento: a, equipe: e),
                        vazio: 'Nenhuma abastecida neste período.',
                      ),
                    ],
                  ),
                  ListaCentral(
                    largura: 900,
                    children: [
                      ListaPorMes<Gasto>(
                        itens: dados.gastos,
                        data: (g) => g.data,
                        valor: (g) => g.valorCentavos,
                        item: (g) => ItemGasto(gasto: g, equipe: e),
                        vazio: 'Nenhum gasto neste período.',
                      ),
                    ],
                  ),
                  ListaCentral(
                    largura: 900,
                    children: [
                      ListaPorMes<Vale>(
                        itens: dados.vales,
                        data: (v) => v.data,
                        valor: (v) => v.valorCentavos,
                        item: (v) => ItemVale(vale: v, equipe: e),
                        vazio: 'Nenhum vale neste período.',
                      ),
                    ],
                  ),
                  if (porViagem) ListaAcertos(motoristaId: m.id),
                  if (comParadas) ListaCentral(largura: 900, children: [CorpoParadasMotorista(motoristaId: m.id)]),
                  _Cadastro(motorista: m),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Acao { caminhao, modalidade, redefinir, ativar, voltar, excluir }

class _MenuMotorista extends ConsumerWidget {
  const _MenuMotorista({required this.motorista});
  final Motorista motorista;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = motorista;
    return PopupMenuButton<_Acao>(
      tooltip: 'Mais ações',
      onSelected: (a) {
        switch (a) {
          case _Acao.caminhao:
            escolherCaminhao(context, ref, m);
          case _Acao.modalidade:
            escolherModalidade(context, ref, m);
          case _Acao.redefinir:
            redefinirAcesso(context, ref, m);
          case _Acao.ativar:
            ativarMotorista(context, ref, m);
          case _Acao.voltar:
            gerarCodigoParaVoltar(context, ref, m);
          case _Acao.excluir:
            excluirMotorista(context, ref, m);
        }
      },
      itemBuilder: (_) => [
        // Quem saiu da empresa fica só como registro: sem login para mexer.
        if (m.semLogin)
          const PopupMenuItem(
            value: _Acao.voltar,
            child: ListTile(leading: Icon(Icons.qr_code_2), title: Text('Gerar código para voltar')),
          )
        else ...[
          const PopupMenuItem(
            value: _Acao.caminhao,
            child: ListTile(leading: Icon(Icons.local_shipping_outlined), title: Text('Trocar o caminhão dele')),
          ),
          const PopupMenuItem(
            value: _Acao.modalidade,
            child: ListTile(leading: Icon(Icons.alt_route), title: Text('Trocar a modalidade dele')),
          ),
          const PopupMenuItem(
            value: _Acao.redefinir,
            child: ListTile(leading: Icon(Icons.key_outlined), title: Text('Redefinir o acesso')),
          ),
          const PopupMenuItem(
            value: _Acao.ativar,
            child: ListTile(leading: Icon(Icons.block), title: Text('Desligar da empresa')),
          ),
        ],
        const PopupMenuItem(
          value: _Acao.excluir,
          child: ListTile(leading: Icon(Icons.delete_forever_outlined), title: Text('Excluir motorista e dados')),
        ),
      ],
    );
  }
}

/// O gestor escolhe em qual caminhão o motorista está agora.
Future<void> escolherCaminhao(BuildContext context, WidgetRef ref, Motorista m) async {
  final e = ref.read(equipeProvider).requireValue;
  final atual = e.caminhaoAtual(m.id);
  final escolhido = await showModalBottomSheet<Caminhao>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.8),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                'Caminhão de ${m.primeiroNome}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
            for (final c in e.caminhoesAtivos)
              ListTile(
                leading: PlacaVeiculo(c.placa, tamanho: 14),
                title: Text(
                  [
                    if (c.numeroFrota != null) 'Frota ${c.numeroFrota}',
                    c.modelo,
                  ].where((t) => t.isNotEmpty).join('  ·  '),
                ),
                subtitle: Text(
                  e.motoristasNoCaminhao(c.id).isEmpty
                      ? 'Livre'
                      : 'Com ${e.motoristasNoCaminhao(c.id).map((x) => x.primeiroNome).join(', ')}',
                ),
                trailing: c.id == atual?.id ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, c),
              ),
            if (e.caminhoesAtivos.isEmpty)
              const Padding(padding: EdgeInsets.all(20), child: Text('Cadastre os caminhões primeiro (em Caminhões).')),
          ],
        ),
      ),
    ),
  );
  if (escolhido == null || escolhido.id == atual?.id || !context.mounted) return;
  final ok = await confirmar(
    context,
    titulo: 'Trocar o caminhão?',
    texto:
        'A partir de agora ${m.primeiroNome} lança no caminhão ${placaTexto(escolhido.placa)}. '
        'O que ele já lançou continua no caminhão antigo. O app dele recebe a troca na próxima conexão.',
    botao: 'Trocar',
  );
  if (!ok || !context.mounted) return;
  await executar(
    context,
    () => ref.read(equipeProvider.notifier).definirCaminhaoAtual(m.id, escolhido.id),
    sucesso: 'Caminhão trocado.',
  );
}

/// O gestor escolhe a modalidade do motorista (entre as ligadas na empresa).
Future<void> escolherModalidade(BuildContext context, WidgetRef ref, Motorista m) async {
  final e = ref.read(equipeProvider).requireValue;
  final atual = m.modalidade == null ? null : e.modalidadeDe(m);
  final escolhida = await showModalBottomSheet<Modalidade>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              'Modalidade de ${m.primeiroNome}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ),
          for (final x in e.modalidadesAtivas)
            ListTile(
              leading: Icon(x.porViagem ? Icons.route_outlined : Icons.local_shipping_outlined),
              title: Text(x.nome),
              subtitle: Text(x.porViagem ? 'Por viagem (carreta, entregas, acerto)' : 'Por frete'),
              trailing: x.codigo == atual?.codigo ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, x),
            ),
          if (e.modalidadesAtivas.length < 2)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Nota('Para ter outras opções, o dono liga mais modalidades em Configurações.'),
            ),
        ],
      ),
    ),
  );
  if (escolhida == null || escolhida.codigo == atual?.codigo || !context.mounted) return;
  final mudaJeito = atual != null && atual.porViagem != escolhida.porViagem;
  final ok = await confirmar(
    context,
    titulo: 'Passar ${m.primeiroNome} para ${escolhida.nome}?',
    texto:
        'O app dele muda na próxima conexão.${mudaJeito ? ' O jeito de lançar muda (${escolhida.porViagem ? 'viagens no lugar de fretes' : 'fretes no lugar de viagens'}). O que ele já lançou continua guardado.' : ''}',
    botao: 'Trocar',
  );
  if (!ok || !context.mounted) return;
  await executar(
    context,
    () => ref.read(equipeProvider.notifier).definirModalidade(m.id, escolhida.codigo),
    sucesso: 'Modalidade trocada.',
  );
}

/// Cria uma senha provisória para o motorista que perdeu o acesso.
Future<void> redefinirAcesso(BuildContext context, WidgetRef ref, Motorista m) async {
  final ok = await confirmar(
    context,
    titulo: 'Redefinir o acesso de ${m.primeiroNome}?',
    texto:
        'Vamos criar uma senha provisória. A senha antiga dele para de funcionar. Ele entra com o CPF '
        'e essa senha, e o app pede para ele criar uma nova.',
    botao: 'Criar senha provisória',
  );
  if (!ok || !context.mounted) return;
  Map<String, Object?>? r;
  await executar(context, () async => r = await ref.read(equipeProvider.notifier).redefinirAcesso(m.id));
  final senha = r?['senha_provisoria']?.toString();
  if (senha == null || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Senha provisória'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Passe para ${m.primeiroNome}. Ela aparece só agora.'),
          const SizedBox(height: 16),
          Center(
            child: SelectableText(senha, style: estiloNumero(34, peso: FontWeight.w700).copyWith(letterSpacing: 4)),
          ),
          const SizedBox(height: 16),
          Text('Ele entra no app com o CPF ${cpfTexto(m.cpf)} e esta senha.'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Clipboard.setData(
            ClipboardData(
              text:
                  'Seu acesso ao Frota Motorista foi redefinido. Entre com o seu CPF e a senha provisória $senha. '
                  'O app vai pedir para você criar uma senha nova.',
            ),
          ),
          child: const Text('Copiar recado'),
        ),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Pronto')),
      ],
    ),
  );
}

/// Desliga o motorista: o login dele fica livre na hora (pode entrar em outra
/// empresa ou voltar com um código novo) e a empresa fica com o registro.
Future<void> ativarMotorista(BuildContext context, WidgetRef ref, Motorista m) async {
  if (!m.ativo) return gerarCodigoParaVoltar(context, ref, m);
  final ok = await confirmar(
    context,
    titulo: 'Desligar ${m.primeiroNome}?',
    texto: 'Ele sai da empresa na hora e o login dele fica livre para entrar em outra empresa. '
        'Aqui fica o registro dele: nome, CPF e tudo o que já mandou (o e-mail sai). '
        'Se ele voltar, gere um código novo: ele começa um cadastro novo.',
    botao: 'Desligar',
    perigo: true,
  );
  if (!ok || !context.mounted) return;
  await executar(
    context,
    () => ref.read(equipeProvider.notifier).ativarMotorista(m.id, false),
    sucesso: 'Motorista desligado. O login dele ficou livre.',
  );
}

/// Quem saiu e quer voltar: gera o código individual com o nome e o CPF do
/// registro. Ele entra num cadastro novo; o registro antigo fica separado.
Future<void> gerarCodigoParaVoltar(BuildContext context, WidgetRef ref, Motorista m) async {
  final e = ref.read(equipeProvider).requireValue;
  final ativas = e.modalidadesAtivas;
  final modalidade = ativas.length > 1 && ativas.any((x) => x.codigo == m.modalidade) ? m.modalidade : null;
  Map<String, Object?>? r;
  final ok = await executar(context, () async {
    r = await ref.read(equipeProvider.notifier).gerarConvite(m.nome, m.cpf, modalidade: modalidade);
  });
  if (!ok || r == null || !context.mounted) return;
  await mostrarConvite(context, Convite.deMapa(r!), e.empresa.nome);
}

/// Exclui o motorista e todos os lançamentos dele. Antes, sempre, o PDF com
/// todos os dados dele (regra aprovada pelo dono); depois, digitar EXCLUIR.
Future<void> excluirMotorista(BuildContext context, WidgetRef ref, Motorista m) async {
  final pdf = await primeiroOPdf(
    context,
    quem: 'de ${m.primeiroNome}',
    gerar: () => baixarDadosMotorista(context, ref, m.id),
  );
  if (!pdf || !context.mounted) return;
  final ok = await confirmarDigitando(
    context,
    titulo: 'Excluir ${m.primeiroNome} e os dados dele?',
    texto:
        'O PDF com todos os dados dele já foi gerado. Agora serão apagados de vez o cadastro dele e todos os fretes, '
        'viagens, acertos, abastecimentos, gastos, vales e paradas dele. Não dá para desfazer. '
        'Para só tirar o acesso e guardar os dados, use "Desligar da empresa".',
    palavra: 'EXCLUIR',
    botao: 'Excluir',
  );
  if (!ok || !context.mounted) return;
  final navegador = Navigator.of(context);
  final feito = await executar(
    context,
    () => ref.read(equipeProvider.notifier).excluirMotorista(m.id),
    sucesso: 'Motorista e dados excluídos.',
  );
  if (feito) navegador.popUntil((r) => r.isFirst);
}

class _Cadastro extends ConsumerWidget {
  const _Cadastro({required this.motorista});
  final Motorista motorista;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = assistirEquipe(ref);
    final m = motorista;
    final agora = ref.read(relogioProvider)();
    final cores = context.cores;
    final caminhao = e.caminhaoAtual(m.id);
    final usos = e.usosDoMotorista(m.id);
    final aparelhos = e.aparelhosDe(m);
    final porViagem = e.porViagem(m.id);
    return ListaCentral(
      largura: 760,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinhaValor(rotulo: 'CPF', valor: cpfTexto(m.cpf)),
              LinhaValor(rotulo: 'E-mail', valor: m.email),
              if ((m.telefone ?? '').isNotEmpty) LinhaValor(rotulo: 'Telefone', valor: m.telefone!),
              LinhaValor(rotulo: 'Último envio', valor: quandoTexto(e.ultimoEnvio(m), agora)),
              const TituloSecao('Modalidade'),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      m.modalidade == null && e.variasModalidades
                          ? 'Ainda não escolhida'
                          : '${e.modalidadeDe(m).nome} (${porViagem ? 'por viagem' : 'por frete'})',
                      style: const TextStyle(fontSize: 16.5),
                    ),
                  ),
                  if (e.variasModalidades || m.modalidade == null)
                    OutlinedButton.icon(
                      onPressed: () => escolherModalidade(context, ref, m),
                      icon: const Icon(Icons.alt_route),
                      label: const Text('Trocar'),
                    ),
                ],
              ),
              TituloSecao(porViagem ? 'Cavalo' : 'Caminhão'),
              Row(
                children: [
                  if (caminhao != null) PlacaVeiculo(caminhao.placa, tamanho: 16) else const Text('Sem caminhão'),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () => escolherCaminhao(context, ref, m),
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Trocar'),
                  ),
                ],
              ),
              if (usos.isNotEmpty) ...[
                const SizedBox(height: 10),
                for (final u in usos)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      '${placaTexto(e.placa(u.caminhaoId))}: de ${dataTexto(u.inicioEm.toLocal())} '
                      '${u.fimEm == null ? 'até agora' : 'a ${dataTexto(u.fimEm!.toLocal())}'}',
                      style: TextStyle(fontSize: 14.5, color: cores.textoFraco),
                    ),
                  ),
              ],
              const TituloSecao('Celulares'),
              if (aparelhos.isEmpty) const Nota('Nenhum celular enviou dados ainda.'),
              for (final a in aparelhos)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(a.revogado ? Icons.phonelink_erase : Icons.smartphone),
                  title: Text(a.apelido),
                  subtitle: Text(
                    a.revogado
                        ? 'Desligado em ${dataTexto(a.revogadoEm!.toLocal())}'
                        : 'Último envio ${quandoTexto(a.ultimoEnvio, agora)}',
                  ),
                  trailing: a.revogado
                      ? null
                      : TextButton(
                          onPressed: () async {
                            final ok = await confirmar(
                              context,
                              titulo: 'Desligar este celular?',
                              texto: 'Ele para de enviar dados. Use quando o celular foi perdido ou trocado.',
                              botao: 'Desligar',
                              perigo: true,
                            );
                            if (ok && context.mounted) {
                              await executar(
                                context,
                                () => ref.read(equipeProvider.notifier).revogarAparelho(a.id),
                                sucesso: 'Celular desligado.',
                              );
                            }
                          },
                          child: const Text('Desligar'),
                        ),
                ),
              const TituloSecao('Acesso'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => baixarDadosMotorista(context, ref, m.id),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Baixar tudo dele (PDF)'),
                  ),
                  if (m.semLogin)
                    OutlinedButton.icon(
                      onPressed: () => gerarCodigoParaVoltar(context, ref, m),
                      icon: const Icon(Icons.qr_code_2),
                      label: const Text('Gerar código para voltar'),
                    )
                  else ...[
                    OutlinedButton.icon(
                      onPressed: () => redefinirAcesso(context, ref, m),
                      icon: const Icon(Icons.key_outlined),
                      label: const Text('Redefinir o acesso'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => ativarMotorista(context, ref, m),
                      icon: const Icon(Icons.block),
                      label: const Text('Desligar da empresa'),
                      style: OutlinedButton.styleFrom(foregroundColor: cores.negativo),
                    ),
                  ],
                  OutlinedButton.icon(
                    onPressed: () => excluirMotorista(context, ref, m),
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: const Text('Excluir motorista e dados'),
                    style: OutlinedButton.styleFrom(foregroundColor: cores.negativo),
                  ),
                ],
              ),
              if (e.exclusaoPedida(m) != null) ...[
                const SizedBox(height: 12),
                Aviso(
                  icone: Icons.delete_outline,
                  titulo: 'Ele excluiu a conta',
                  texto:
                      'Em ${dataTexto(e.exclusaoPedida(m)!)} ele excluiu a conta e o login dele foi apagado. '
                      'Os lançamentos ficam até ${dataTexto(e.exclusaoPedida(m)!.add(prazoExclusaoMotorista))} '
                      'e depois são apagados sozinhos. Baixe antes o PDF com todos os dados dele (botão "Baixar tudo dele"). '
                      'Se ele voltar, use "Gerar código para voltar": ele começa um cadastro novo.',
                ),
              ],
              const SizedBox(height: 8),
              const Nota(
                'Redefinir o acesso serve para quem perdeu a senha e o e-mail: você passa uma senha provisória e ele troca no primeiro login.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
