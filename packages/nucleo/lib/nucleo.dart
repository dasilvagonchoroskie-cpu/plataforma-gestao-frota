/// Núcleo compartilhado da Plataforma de Gestão de Frota: modelos, regras de
/// cálculo (portadas do Meu Frete), formatos e relatórios em PDF e CSV.
/// As contas existem só aqui; o banco guarda os dados e não repete fórmulas.
library;

export 'src/cpf.dart';
export 'src/email.dart';
export 'src/formato.dart';
export 'src/modalidades.dart';
export 'src/modelos.dart';
export 'src/paradas.dart';
export 'src/placa.dart';
export 'src/regras/ajustes.dart';
export 'src/regras/dados_relatorio.dart';
export 'src/regras/media_diesel.dart';
export 'src/regras/periodo.dart';
export 'src/regras/resumo.dart';
export 'src/senha.dart';
export 'src/relatorio/csv.dart';
export 'src/relatorio/gerador_pdf.dart';
