import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'banco.g.dart';

/// Cada registro do motorista guardado como o mesmo JSON do servidor
/// (nomes das colunas do banco). Assim o celular, a fila e a nuvem falam a
/// mesma língua e o banco local não repete regra nenhuma.
class Registros extends Table {
  TextColumn get tabela => text()();
  TextColumn get id => text()();
  TextColumn get dados => text()();

  @override
  Set<Column> get primaryKey => {tabela, id};
}

/// Fila de envio: o que foi gravado no celular e ainda não chegou na nuvem.
/// Só sai da fila depois que o servidor confirma.
class FilaEnvio extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get tabela => text()();
  TextColumn get registroId => text()();
  TextColumn get dados => text()();
  IntColumn get versao => integer().withDefault(const Constant(1))();
  TextColumn get situacao => text().withDefault(const Constant('pendente'))();
  TextColumn get mensagem => text().nullable()();
  DateTimeColumn get criadoEm => dateTime().withDefault(currentDateAndTime)();
}

/// Pequenos valores guardados (última sincronização, aparelho, situação).
class Estado extends Table {
  TextColumn get chave => text()();
  TextColumn get valor => text().nullable()();

  @override
  Set<Column> get primaryKey => {chave};
}

@DriftDatabase(tables: [Registros, FilaEnvio, Estado])
class BancoLocal extends _$BancoLocal {
  BancoLocal([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'frota_motorista'));

  @override
  int get schemaVersion => 1;
}
