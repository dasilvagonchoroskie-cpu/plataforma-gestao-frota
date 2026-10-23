import 'dart:io';
import 'dart:typed_data';

import 'package:nucleo/nucleo.dart';
import 'package:test/test.dart';

FontesPdf fontes() {
  ByteData ler(String nome) => ByteData.sublistView(File('lib/fontes/$nome').readAsBytesSync());
  final a = FontesPdf.arquivos;
  return FontesPdf.deBytes(ler(a[0]), ler(a[1]), ler(a[2]), ler(a[3]));
}

void main() {
  final agora = DateTime(2026, 10, 23, 9);

  Frete frete(String id, int dia) => Frete(
        id: id, motoristaId: 'm1', caminhaoId: 'c1', origem: 'Jataí', destino: 'Paranaguá', dataCarga: DateTime(2026, 3, dia),
        pesoCargaKg: 37000, valorToneladaCentavos: 21000, adiantamentoCentavos: 500000, percentualComissao: 13,
      );

  test('todo o histórico: do primeiro registro até hoje', () {
    final p = periodoCompleto([DateTime(2026, 5, 2, 15), DateTime(2026, 3, 9, 8)], agora);
    expect(p.inicio, DateTime(2026, 3, 9));
    expect(p.contem(agora), isTrue);
    expect(periodoCompleto(const [], agora).contem(agora), isTrue, reason: 'sem nada lançado, só hoje');
  });

  test('arquivo da empresa: capa, caminhões, cada motorista com relatório, acertos e paradas', () async {
    final fretes = [for (var i = 1; i <= 40; i++) frete('f$i', (i % 28) + 1)];
    final periodo = periodoCompleto(fretes.map((f) => f.dataCarga), agora);
    final relatorio = montarDados(
      fretes: fretes, abastecimentos: const [], vales: const [], gastos: const [], ajustes: const [],
      periodo: periodo, regras: const Regras(), motorista: 'João Batista', empresa: 'Transportes X',
    );
    const motivos = [
      MotivoParada(codigo: 'refeicao', nome: 'Refeição', contaComoDescanso: true),
      MotivoParada(codigo: 'cafe', nome: 'Café ou pausa curta'),
    ];
    final paradas = [
      Parada(id: 'p1', motoristaId: 'm1', motivo: 'refeicao', inicioEm: DateTime(2026, 3, 5, 12), fimEm: DateTime(2026, 3, 5, 13)),
      Parada(id: 'p2', motoristaId: 'm1', motivo: 'cafe', inicioEm: DateTime(2026, 3, 5, 16), fimEm: DateTime(2026, 3, 5, 16, 10)),
    ];
    final d = DadosArquivo(
      empresa: 'Transportes X',
      caminhoes: const [Caminhao(id: 'c1', placa: 'ABC1D23', numeroFrota: '07', modelo: 'Scania R450', ano: 2021)],
      motoristas: [
        MotoristaNoArquivo(
          nome: 'João Batista', cpf: '111.444.777-35', email: 'joao@teste.com', modalidade: 'Graneleiro',
          relatorio: relatorio,
          acertos: [
            Acerto(
              id: 'a1', motoristaId: 'm1', periodoInicio: DateTime(2026, 3, 1), periodoFim: DateTime(2026, 3, 15),
              comissaoCentavos: 150000, descontos: const [DescontoAcerto(descricao: 'Multa', valorCentavos: 10000)],
              totalDescontosCentavos: 10000, valesCentavos: 20000, paraReceberCentavos: 120000, fechadoEm: DateTime(2026, 3, 16),
            ),
          ],
          paradas: DadosParadas(
            periodo: periodo, motivos: motivos, empresa: 'Transportes X', motorista: 'João Batista',
            resumo: resumirParadas(paradas: paradas, motivos: motivos, periodo: periodo, limiteMinutos: 330, agora: agora),
          ),
        ),
        MotoristaNoArquivo(
          nome: 'Pedro Henrique', ativo: false,
          relatorio: montarDados(
            fretes: const [], abastecimentos: const [], vales: const [], gastos: const [], ajustes: const [],
            periodo: periodo, regras: const Regras(), motorista: 'Pedro Henrique',
          ),
        ),
      ],
    );
    final bytes = await gerarPdfArquivo(d, fontes(), agora: agora);
    expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
    expect(bytes.length, greaterThan(20000));
    Directory('build').createSync(recursive: true);
    File('build/exemplo_arquivo_empresa.pdf').writeAsBytesSync(bytes);
    expect(nomeDoArquivoDeDados(d, agora), 'Frota_arquivo_Transportes_X_23-10-2026.pdf');

    final soDele = DadosArquivo(empresa: 'Transportes X', motoristas: [d.motoristas.first], daEmpresaToda: false);
    expect(nomeDoArquivoDeDados(soDele, agora), 'Frota_arquivo_Joao_23-10-2026.pdf');
    expect((await gerarPdfArquivo(soDele, fontes(), agora: agora)).length, greaterThan(10000));
  });
}
