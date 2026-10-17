import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:visual/visual.dart';

import '../../componentes/comuns.dart';
import '../../componentes/itens.dart';
import '../../dados/equipe.dart';
import '../../dados/modelos.dart';
import '../../dados/provedores.dart';
import '../../relatorio/compartilhar.dart';

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

    return DefaultTabController(
      length: 6,
      initialIndex: abaInicial,
      child: Scaffold(
        appBar: AppBar(
          title: Text(m.nome),
          actions: [
            const BotaoAtualizar(),
            _MenuMotorista(motorista: m),
            const SizedBox(width: 4),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Como ele vê'),
              Tab(text: 'Fretes'),
              Tab(text: 'Diesel'),
              Tab(text: 'Gastos'),
              Tab(text: 'Vales'),
              Tab(text: 'Cadastro'),
            ],
          ),
        ),
        body: Column(
          children: [
            const SizedBox(height: 8),
            const Centro(largura: 900, child: FaixaPeriodo()),
            if (!m.ativo)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Aviso(
                  icone: Icons.block,
                  titulo: 'Motorista desligado',
                  texto: 'Ele não consegue mais enviar lançamentos. O que já mandou continua aqui.',
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
                        child: CorpoResumo(
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

enum _Acao { caminhao, redefinir, ativar, excluir }

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
          case _Acao.redefinir:
            redefinirAcesso(context, ref, m);
          case _Acao.ativar:
            ativarMotorista(context, ref, m);
          case _Acao.excluir:
            excluirMotorista(context, ref, m);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: _Acao.caminhao,
          child: ListTile(leading: Icon(Icons.local_shipping_outlined), title: Text('Trocar o caminhão dele')),
        ),
        const PopupMenuItem(
          value: _Acao.redefinir,
          child: ListTile(leading: Icon(Icons.key_outlined), title: Text('Redefinir o acesso')),
        ),
        PopupMenuItem(
          value: _Acao.ativar,
          child: ListTile(
            leading: Icon(m.ativo ? Icons.block : Icons.check_circle_outline),
            title: Text(m.ativo ? 'Desligar da empresa' : 'Religar na empresa'),
          ),
        ),
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

Future<void> ativarMotorista(BuildContext context, WidgetRef ref, Motorista m) async {
  final ok = await confirmar(
    context,
    titulo: m.ativo ? 'Desligar ${m.primeiroNome}?' : 'Religar ${m.primeiroNome}?',
    texto: m.ativo
        ? 'Ele para de enviar lançamentos e de ver os dados da empresa na próxima vez que o app conectar. '
              'Nada do que ele já mandou é apagado.'
        : 'Ele volta a enviar lançamentos para o painel.',
    botao: m.ativo ? 'Desligar' : 'Religar',
    perigo: m.ativo,
  );
  if (!ok || !context.mounted) return;
  await executar(
    context,
    () => ref.read(equipeProvider.notifier).ativarMotorista(m.id, !m.ativo),
    sucesso: m.ativo ? 'Motorista desligado.' : 'Motorista religado.',
  );
}

/// Exclui o motorista e todos os lançamentos dele (digitando EXCLUIR).
Future<void> excluirMotorista(BuildContext context, WidgetRef ref, Motorista m) async {
  final ok = await confirmarDigitando(
    context,
    titulo: 'Excluir ${m.primeiroNome} e os dados dele?',
    texto:
        'Serão apagados de vez o cadastro dele e todos os fretes, abastecimentos, gastos e vales que ele lançou. '
        'Antes, baixe o relatório dele (PDF ou planilha) se a empresa precisar guardar. Não dá para desfazer. '
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
              const TituloSecao('Caminhão'),
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
                    onPressed: () => redefinirAcesso(context, ref, m),
                    icon: const Icon(Icons.key_outlined),
                    label: const Text('Redefinir o acesso'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => ativarMotorista(context, ref, m),
                    icon: Icon(m.ativo ? Icons.block : Icons.check_circle_outline),
                    label: Text(m.ativo ? 'Desligar da empresa' : 'Religar na empresa'),
                    style: m.ativo ? OutlinedButton.styleFrom(foregroundColor: cores.negativo) : null,
                  ),
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
                  titulo: 'Ele pediu para excluir a conta',
                  texto:
                      'Pedido feito em ${dataTexto(e.exclusaoPedida(m)!)}. O acesso dele já foi encerrado e os dados '
                      'serão apagados sozinhos em ${dataTexto(e.exclusaoPedida(m)!.add(const Duration(days: 15)))}. '
                      'Baixe antes o que a empresa precisar guardar.',
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
