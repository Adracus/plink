part of plink;

const ID = "id";
const TARGET_ID = "targetId";
const TARGET_TABLE = "targetTable";

const PRIMITIVES = const[int, double, String, DateTime];


class Relation implements WeakSchema {
  final SchemaIndex index;
  final Symbol sourceName;
  final Symbol qualifiedName;
  final Symbol simpleName;
  final Type type;
  final FieldCombination fields = new FieldCombination(
      [new Field(const Symbol(ID), int, [KEY]),
       new Field(const Symbol(TARGET_ID), int, [KEY]),
       new Field(const Symbol(TARGET_TABLE), String, [KEY])]);

  Relation.fromField(VariableMirror field, ClassMirror source, this.index)
      : sourceName = source.qualifiedName,
        simpleName = field.simpleName,
        qualifiedName = field.qualifiedName,
        type = field.type.reflectedType;
  
  
  Future<Set<int>> where(s.Operator operator) {
    if (!PRIMITIVES.contains(type)) throw "Only primitive types are supported";
    return index.getAdapter().then((adapter) {
      var schema = index.schemaFor(type);
      var st = s.select([s.i(str(name), ID)], s.from(str(schema.name)), s.innerJoin(str(name),
          s.on(s.i(str(name), TARGET_ID), s.i(str(schema.name), ID))),
          s.where(operator..identifier = s.c("value")));
      var preparedStatement = adapter.statementConverter.convertSelectStatement(st);
      return adapter.select(preparedStatement).then((vals) {
        return vals.map((row) => row[ID]).toSet();
      });
    });
  }
  

  Future find(int sourceId) => index.getAdapter().then((adapter) {
    return fetchRecord(adapter, sourceId).then((record) {
      return index.schemaFor(record[TARGET_TABLE])
                  .find(record[TARGET_ID]);
    });
  });
  
  
  Future<List> all() => index.getAdapter().then((adapter) {
    return adapter.where(str(name), {}).then((records) =>
        Future.wait(records.map(valueFromRecord)));
  });
  
  
  Future valueFromRecord(Map<String, dynamic> record) =>
      index.schemaFor(record[TARGET_TABLE])
           .find(record[TARGET_ID]);
  
  
  Symbol get name => combineSymbols(sourceName, simpleName);
  
  Future save(int sourceId, element, {bool deep: false}) =>
      index.getAdapter().then((adapter) {
    if (null == sourceId) throw "Source id cannot be null";
    var schema = index.schemaFor(element.runtimeType) as StrongSchema;
    return schema.save(element, deep: deep).then((saved) {
      return adapter.insert(str(name), {ID: sourceId, TARGET_ID: saved.id,
                                        TARGET_TABLE: str(schema.name)})
                    .then((_) => element);
    });
  });
  
  
  Future delete(int sourceId, {bool deep: false}) =>
      index.getAdapter().then((adapter) {
    if (!deep) return _deleteRelationLink(adapter, sourceId);
    return fetchRecord(adapter, sourceId).then((record) {
      return index.schemaFor(record[TARGET_TABLE]).delete(record[TARGET_ID])
          .then((_) => _deleteRelationLink(adapter, sourceId));
    });
  });
  
  Future _deleteRelationLink(DatabaseAdapter adapter, int sourceId) {
    return adapter.delete(str(name), {ID: sourceId});
  }
  
  Future<Map<String, dynamic>> fetchRecord(DatabaseAdapter adapter, int sourceId) =>
      adapter.where(str(name), {ID: sourceId}).then((results) => 1 == results.length ?
          results.single : null);

  toString() => "Relation '${str(name)}'";
  
  
  Future drop() => index.getAdapter().then((adapter) {
    return adapter.dropTable(str(name));
  });
  
  
  bool get needsPersistance => true;
}