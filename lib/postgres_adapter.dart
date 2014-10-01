library plink.postgres_adapter;

import 'dart:async' show Future;
import 'package:u_til/u_til.dart';
import 'package:plink/plink.dart';
import 'package:postgresql/postgresql.dart';

class PostgresAdapter implements DatabaseAdapter {
  final Uri _uri;
  
  
  PostgresAdapter(uri)
      : _uri = uri is Uri ? uri : Uri.parse(uri);
  
  
  Future<Connection> obtainConnection() => connect(_uri.toString());
  
  
  Future<int> _execute(String sql, [values]) =>
      obtainConnection().then((conn) {
    return conn.execute(sql, values).whenComplete(() => conn.close());
  });
  
  
  Future<List<Row>> _query(String sql, [values]) =>
      obtainConnection().then((conn) {
    return conn.query(sql, values).toList().whenComplete(() => conn.close());
  });
  
  
  Future<bool> hasTable(String tableName) {
    return obtainConnection().then((conn) {
      return conn.query("SELECT EXISTS (" +
                   "SELECT table_name " +
                   "FROM information_schema.tables " +
                   "WHERE table_schema = 'public' " +
                   "AND table_name = '${tableName.toLowerCase()}' "
                 ")")
          .toList().then((rows) {
        return rows.first[0];})
          .whenComplete(() => conn.close());
    });
  }
  
  
  Future createTable(String tableName, List<FieldSchema> fields) {
    var variables = fields.map(variableForCreate).join(", ");
    return _execute("CREATE TABLE $tableName ($variables)").then((_) =>
        new Future.value());
  }
  
  
  String getType(FieldSchema variable) {
    if (variable.constraints.any((elem) =>
        elem is AutoIncrement)) return "serial";
    if (variable.type == "string") return "text";
    if (variable.type == "int") return "integer";
    if (variable.type == "double") return "double precision";
    if (variable.type == "datetime") return "timestamp";
    throw new UnsupportedError("Type '${variable.type}' not supported");
  }
  
  
  String variableForCreate(FieldSchema variable) {
    var type = getType(variable);
    return ("${variable.name} $type " +
        variable.constraints.map(constraintsForCreate).join(" ")).trim();
  }
  
  
  static String constraintsForCreate(constraint) {
    if (constraint is PrimaryKey) return "primary key";
    if (constraint is Unique) return "unique";
    return "";
  }
  
  
  Future<List<Map<String, dynamic>>> all(String tableName) {
    return obtainConnection().then((conn) {
      return conn.query("SELECT * FROM $tableName")
          .toList().then((rows) => transformRows(rows))
          .whenComplete(() => conn.close());
    });
  }
  
  
  Future delete(String tableName, Map<String, dynamic> condition) {
    return _execute("DELETE FROM $tableName WHERE " +
        "${generateWhereClause(condition.keys)}", condition)
          .then((res) => new Future.value());
  }
  
  
  Future dropTable(String tableName) {
    return obtainConnection().then((conn) {
      return conn.execute("DROP TABLE $tableName")
                 .then((res) => new Future.value())
                 .whenComplete(() => conn.close());
    });
  }
  
  
  Future<List<Map<String, dynamic>>> findWhere(String tableName,
      Map<String, dynamic> condition) =>
      _query("SELECT * FROM $tableName WHERE " +
          generateWhereClause(condition.keys), condition).then(transformRows);
  
  
  List<Map<String, dynamic>> transformRows(List<Row> rows) =>
      rows.map(rowToMap).toList();
  
  
  Map<String, dynamic> rowToMap(Row row) {
    var result = {};
    row.forEach((name, value) => result[name] = value);
    return result;
  }
  
  
  String generateWhereClause(Iterable<String> keyNames) =>
      keyNames.map((k) => "$k = @$k").join(" AND ");
  
  
  Future<Map<String, dynamic>> saveToTable(String tableName,
      Map<String, dynamic> values) {
    var keyNames = values.keys.join(", ");
    var keySubs = values.keys.map((name) => "@$name").join(", ");
    return _query("INSERT INTO $tableName ($keyNames) VALUES " + 
                          "($keySubs) RETURNING *", values)
                 .then((rows) => transformRows(rows).first);
  }
  
  
  Future<Map<String, dynamic>> updateToTable(String tableName,
      Map<String, dynamic> values, Map<String, dynamic> condition) {
    var id = values.remove("id");
    var substitutes = {}..addAll(values)..addAll(condition);
    var keyNames = values.keys.join(", ");
    var keySubs = values.keys.map((name) => "@$name").join(", ");
    return _query("UPDATE $tableName SET ($keyNames) = ($keySubs)" +
                          " WHERE ${generateWhereClause(condition.keys)}" +
                          "RETURNING *", substitutes)
                 .then((rows) => transformRows(rows).first);
  }
}