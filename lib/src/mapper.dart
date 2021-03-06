part of plink;

StrongSchema _schemaFor(SchemaIndex index, arg) {
  if (arg is! Identifyable) throw new ArgumentError("$arg is not supported");
  if (arg is Mapped) return index.schemaFor(arg.value.runtimeType);
  return index.schemaFor(arg.runtimeType);
}

_value(arg) {
  if (arg is! Identifyable) throw new ArgumentError();
  if (arg is Mapped) return arg.value;
  return arg;
}


abstract class Mapper<T> implements StrongSchema {
  SchemaIndex get index;
  
  Future<T> find(int id);
  Future<Mapped<T>> save(T element, {bool deep: false});
  
  static Type getMapperType(Mapper mapper) {
    var clazz = reflect(mapper).type;
    var typeArgs = clazz.typeVariables;
    return typeArgs.single.reflectedType;
  }
  
  bool matches(Type type);
  
  static List<Mapper> generateMappers(SchemaIndex index) {
    var classMap = $.rootLibrary.getClasses();
    var mapperClasses = classMap.values.where((clazz) =>
        !clazz.isAbstract && clazz.isSubtypeOf(reflectType(Mapper)));
    var mappers = mapperClasses.map((clazz) =>
        clazz.newInstance(const Symbol(''), [index]).reflectee).toList();
    return mappers;
  }
}

class Mapped<E> implements Identifyable {
  final E value;
  final int id;
  
  Mapped(this.id, this.value);
}


abstract class PrimitiveMapper<T> implements Mapper<T> {
  SchemaIndex get index;
  
  FieldCombination get fields => new FieldCombination(
        [new Field(#id, int, [KEY, AUTO_INCREMENT]),
         new Field(#value, valueType)]);
  
  Type get valueType;
  
  Future<Mapped<T>> save(T element, {bool deep: false}) =>
      index.getAdapter().then((adapter) {
    return adapter.insert(str(name), {"value": element}).then((res) {
      var id = res["id"];
      var value = res["value"];
      return new Mapped<T>(id, value);
    });
  });
  
  Future<T> find(int id) => index.getAdapter().then((adapter) {
    return adapter.where(str(name), {"id": id}).then((res) {
      return res["value"];
    });
  });
  
  Future delete(int id, {bool deep: false}) =>
      index.getAdapter().then((adapter) {
    return adapter.delete(str(name), {"id": id});
  });
  
  Future drop() => index.getAdapter().then((adapter) =>
      adapter.dropTable(str(name)));
  
  Future<List<T>> all() => index.getAdapter().then((adapter) {
    return adapter.where(str(name), {}).then((res) {
      return res.map((row) => row["value"]).toList();
    });
  });
  
  bool get needsPersistance => true;
}


abstract class ConvertMapper<T, E> implements Mapper<T> {
  SchemaIndex get index;
  
  FieldCombination get fields => new FieldCombination._empty();
  Mapper get coveredMapper;
  
  Future drop() => new Future.value();
  
  T decode(E element);
  E encode(T element);
  
  bool get needsPersistance => false;
  
  Future<Mapped<T>> save(T element, {bool deep: false}) {
    return coveredMapper.save(encode(element), deep: deep).then((mapped) =>
        new Mapped(mapped.id, decode(mapped.value)));
  }
  
  Future<T> find(int id) => coveredMapper.find(id)
    .then((loaded) => decode(loaded));
  
  Future delete(int id, {bool deep: false}) =>
      coveredMapper.delete(id, deep: deep);
  
  Future<List<T>> all() => coveredMapper.all()
      .then((loaded) => loaded.map((E element) => decode(element)).toList());
}


class StringMapper extends Object with PrimitiveMapper<String> {
  static final Symbol className = reflectClass(StringMapper).qualifiedName;
  final SchemaIndex index;
  
  StringMapper(this.index);
  
  final Type valueType = String;
  Symbol get name => className;
  
  bool matches(Type type) => String == type;
}


class BoolMapper extends Object with PrimitiveMapper<bool> {
  static final Symbol className = reflectClass(BoolMapper).qualifiedName;
  final SchemaIndex index;
  
  BoolMapper(this.index);
  
  final Type valueType = bool;
  Symbol get name => className;
  
  bool matches(Type type) => bool == type;
}


class DoubleMapper extends Object with PrimitiveMapper<double> {
  static final Symbol className = reflectClass(DoubleMapper).qualifiedName;
  final SchemaIndex index;
  
  DoubleMapper(this.index);
  
  final Type valueType = double;
  Symbol get name => className;
  bool matches(Type type) => double == type;
}


class IntMapper extends PrimitiveMapper<int> {
  static final Symbol className = reflectClass(IntMapper).qualifiedName;
  final SchemaIndex index;
  final Type valueType = int;
  
  IntMapper(this.index);
  
  Symbol get name => className;
  bool matches(Type type) => int == type;
}


class DateTimeMapper extends PrimitiveMapper<DateTime> {
  static final Symbol className = reflectClass(DateTimeMapper).qualifiedName;
  final SchemaIndex index;
  
  DateTimeMapper(this.index);
  
  Type get valueType => DateTime;
  Symbol get name => className;
  bool matches(Type type) => DateTime == type;
}


class NullMapper implements Mapper<Null> {
  static final Symbol className = reflectClass(NullMapper).qualifiedName;
  final SchemaIndex index;
  
  NullMapper(this.index);
  
  FieldCombination get fields => new FieldCombination(
          [new Field(#id, int, [KEY])]);
  
  Future<Mapped<Null>> save(Null element, {bool deep: false}) =>
      new Future.value(new Mapped<Null>(1, null));
  
  
  Future<Null> find(int id) => new Future.value(null);
  
  Future delete(int id, {bool deep: false}) => new Future.value();
  
  Symbol get name => className;
  
  bool get needsPersistance => false;
  
  Future drop() => new Future.value();
  
  bool matches(Type type) => Null == type;
  
  Future<List<Null>> all() => new Future.value([null]);
}

class SymbolMapper extends Object with ConvertMapper<Symbol, String> {
  static final Symbol className = reflectClass(SymbolMapper).qualifiedName;
  final Mapper coveredMapper;
  final SchemaIndex index;
  
  SymbolMapper(SchemaIndex index)
      : index = index,
        coveredMapper = new StringMapper(index);
  
  Symbol decode(String element) => new Symbol(element);
  String encode(Symbol element) => str(element);
  
  Symbol get name => className;
  
  bool matches(Type type) =>
      reflectType(type).isAssignableTo(reflectType(Symbol));
}


class UriMapper extends Object with ConvertMapper<Uri, String> {
  static final Symbol className = reflectClass(UriMapper).qualifiedName;
  final Mapper coveredMapper;
  final SchemaIndex index;
  
  UriMapper(SchemaIndex index)
      : index = index,
        coveredMapper = new StringMapper(index);
  
  Uri decode(String element) => Uri.parse(element);
  String encode(Uri element) => element.toString();
  
  Symbol get name => className;
  
  bool matches(Type type) => Uri == type;
}


class ListMapper implements Mapper<List> {
  static final Symbol className = reflectClass(ListMapper).qualifiedName;
  final SchemaIndex index;
  
  ListMapper(this.index);
  
  final FieldCombination fields = new FieldCombination(
      [new Field(#id, int, [KEY, AUTO_INCREMENT]),
       new Field(#index, int, [KEY]),
       new Field(#targetTable, String, [KEY]),
       new Field(#targetId, int, [KEY])]);
  
  Future<Mapped<List>> save(List element, {bool deep: false}) =>
      index.getAdapter().then((adapter) {
    var fs = [];
    for (int i = 0; i < element.length; i++) {
      fs.add(_saveSingle(adapter, element[i], deep: deep));
    }
    return Future.wait(fs).then(_persistListLink).then((id) =>
        new Mapped<List>(id, element));
  });
  
  Future<Identifyable> _saveSingle(DatabaseAdapter adapter, element, {bool deep: false}) {
    var schema = index.schemaFor(element.runtimeType) as StrongSchema;
    if (!deep) { // If non deep, check for identifyables to be saved
      if (element is Identifyable) {
        if (element.id == null) // Non-Persisted model
          throw "No non-Deep save for unsaved model"; // means an error if non-deep
        return (new Future.value(element)); // No saving or updating for models
      }
      return schema.save(element, deep: deep); // Primitive values are saved
    }
    return schema.save(element, deep: deep); // If deep, always save(persisted ones will be updated)
  }
  
  Future<int> _persistListLink(List<Identifyable> element) => index.getAdapter().then((adapter) {
    if (element.length == 0) return adapter.insert(str(name), {"index": 0,
      "targetTable": "", "targetId": 0}).then((row) => row["id"]);
    var first = element.first;
    return adapter.insert(str(name), {"index": 0, "targetTable":
        str(index.schemaFor(first.value.runtimeType).name),
        "targetId": first.id}).then((rec) {
      var id = rec["id"];
      var fs = [];
      for (int i = 1; i < element.length; i++) {
        fs.add(_saveSingleElement(adapter, element[i], id, i));
      }
      return Future.wait(fs).then((_) => id);
    });
  });
  
  Future _saveSingleElement(DatabaseAdapter adapter, Mapped element, int id, int i) {
    var targetTable = str(index.schemaFor(element.value.runtimeType).name);
    return adapter.insert(str(name), {"id": id, "index": i, "targetTable": targetTable,
      "targetId": element.id});
  }
  
  Future delete(int id, {bool deep: false}) =>
      index.getAdapter().then((adapter) {
    if (!deep) return deleteListLink(adapter, id);
    return adapter.where(str(name), {"id": id}).then((rows) {
      if (_isEmptyListResult(rows)) return deleteListLink(adapter, id);
      return Future.wait(rows.map((row) => _deleteItem(adapter, row, deep: deep)))
          .then((_) =>
              deleteListLink(adapter, id));
    });
  });
  
  Future deleteListLink(DatabaseAdapter adapter, int id) {
    return adapter.delete(str(name), {"id": id});
  }
  
  Future<List<List>> all() => index.getAdapter().then((adapter) {
    return adapter.where(str(name), {}).then((records) {
      var listRows = seperateListRows(records);
      return Future.wait(listRows.map(listFromRows));
    });
  });
  
  List<List<Map<String, dynamic>>> seperateListRows(
      List<Map<String, dynamic>> rows) {
    var proto = {};
    rows.forEach((row) {
      var id = row["id"];
      if (null == proto[id]) {
        proto[id] = [row];
        return;
      }
      proto[id].add(row);
    });
    return proto.values.toList();
  }
  
  Future<List> find(int id) => index.getAdapter().then((adapter) {
    return adapter.where(str(name), {"id": id}).then(listFromRows);
  });
  
  Future<List> listFromRows(List<Map<String, dynamic>> rows) {
    if (_isEmptyListResult(rows)) return new Future.value([]);
    var fs = [];
    var result = new List.generate(rows.length, (_) => null, growable: true);
    return Future.wait(rows.map((row) => _loadItemFromRow(row).then((loaded) {
      result[row["index"]] = loaded;
    }))).then((_) => result);
  }
  
  
  Future _deleteItem(DatabaseAdapter adapter, Map<String, dynamic> row,
                    {bool deep: false}) {
    return index.schemaFor(row["targetTable"]).delete(row["targetId"], deep: deep);
  }
  
  
  Future _loadItemFromRow(Map<String, dynamic> row) {
    var schema = index.schemaFor(row["targetTable"]);
    return schema.find(row["targetId"]);
  }
  
  
  bool _isEmptyListResult(List<Map<String, dynamic>> rows) {
    return 1 == rows.length && rows.single["targetTable"] == "";
  }
  
  Symbol get name => className;
  
  bool get needsPersistance => true;
  
  Future drop() =>
      index.getAdapter().then((adapter) => adapter.dropTable(str(name)));
  
  bool matches(Type type) => reflectType(type).isAssignableTo(reflectType(List));
}


class SetMapper extends Object with ConvertMapper<Set, List> {
  static final Symbol className = reflectClass(SetMapper).qualifiedName;
  final SchemaIndex index;
  final Mapper coveredMapper;
  
  SetMapper(SchemaIndex index)
      : index = index,
        coveredMapper = new ListMapper(index);
  
  List encode(Set element) => element.toList();
  Set decode(List element) => element.toSet();
  
  Symbol get name => className;
  
  bool matches(Type type) => reflectType(type).isAssignableTo(reflectType(Set));
}


class MapMapper implements Mapper<Map> {
  static final Symbol className = reflectClass(MapMapper).qualifiedName;
  final SchemaIndex index;
  final FieldCombination fields = new FieldCombination(
      [new Field(#id, int, [KEY, AUTO_INCREMENT]),
       new Field(#keyId, int, [KEY]),
       new Field(#keyTable, String, [KEY]),
       new Field(#valueId, int, [KEY]),
       new Field(#valueTable, String, [KEY])]);
  
  MapMapper(this.index);
 
  Symbol get name => className;
  
  bool matches(Type type) => reflectType(type).isAssignableTo(reflectType(Map));
  
  Future<List<Map>> all() => index.getAdapter().then((adapter) {
    return adapter.where(str(name), {}).then((records) {
      return Future.wait(seperateMapRows(records).map((record) =>
          mapFromRecords(records, adapter)));
    });
  });
  
  Future<Map> find(int id) => index.getAdapter().then((adapter) {
    return adapter.where(str(name), {"id": id}).then((records) {
      return mapFromRecords(records, adapter);
    });
  });
  
  List<List<Map<String, dynamic>>> seperateMapRows(
      List<Map<String, dynamic>> rows) {
    var proto = {};
    rows.forEach((row) {
      var id = row["id"];
      if (null == proto[id]) {
        proto[id] = [row];
        return;
      }
      proto[id].add(row);
    });
    return proto.values.toList();
  }
  
  Future<Map> mapFromRecords(List<Map<String, dynamic>> records,
      DatabaseAdapter adapter) {
    if (_isEmptyMapResult(records)) return new Future.value({});
    return Future.wait(records.map((record) =>
        _loadPair(adapter, record))).then((pairs) {
      return KeyValuePair.mapFromKeyValues(pairs);
    });
  }
  
  Future<KeyValuePair> _loadPair(DatabaseAdapter adapter, Map<String, dynamic> row) {
    var key, value;
    var keySchema = index.schemaFor(row["keyTable"]);
    var valueSchema = index.schemaFor(row["valueTable"]);
    var fs = [];
    fs.add(keySchema.find(row["keyId"]).then((k) => key = k));
    fs.add(valueSchema.find(row["valueId"]).then((v) => value = v));
    return Future.wait(fs).then((_) => new KeyValuePair(key, value));
  }
  
  bool _isEmptyMapResult(List<Map<String, dynamic>> rows) {
    return rows.length == 1 && rows.single["keyTable"] == ""
                            && rows.single["valueTable"] == ""
                            && rows.single["keyId"] == 0
                            && rows.single["valueId"] == 0;
  }
  
  Future<Mapped<Map>> save(Map element, {bool deep: false}) =>
      index.getAdapter().then((adapter) {
    if (0 == element.length) return _saveEmptyMapLink(adapter);
    var pairs = KeyValuePair.flattenMap(element);
    return Future.wait(pairs.map((pair) => _savePair(adapter, pair))).then((savedPairs) {
      return _saveMapLink(adapter, savedPairs).then((id) => new Mapped(id, element));
    });
  });
  
  Future<int> _saveEmptyMapLink(DatabaseAdapter adapter) {
    return adapter.insert(str(name), {"keyId": 0,
      "keyTable": "", "valueId": 0, "valueTable": ""}).then((savedRow) {
      return new Mapped(savedRow["id"], {});
    });
  }
  
  Future<int> _saveMapLink(DatabaseAdapter adapter,
      List<KeyValuePair<Identifyable, Identifyable>> pairs) {
    var first = pairs.first;
    var keyTableName = str(_schemaFor(index, first.key).name);
    var valueTableName = str(_schemaFor(index, first.value).name);
    return adapter.insert(str(name), {"keyId": first.key.id, "keyTable": keyTableName,
      "valueId": first.value.id, "valueTable": valueTableName}).then((rec) {
      var id = rec["id"];
      if (pairs.length == 1) return new Future.value(id);
      var fs = [];
      for (int i = 1; i < pairs.length; i++) {
        keyTableName = str(_schemaFor(index, pairs[i].key).name);
        valueTableName = str(_schemaFor(index, pairs[i].value).name);
        fs.add(adapter.insert(str(name), {"keyId": pairs[i].key.id,
          "keyTable": keyTableName, "valueId": pairs[i].value.id,
          "valueTable": valueTableName, "id": id}));
      }
      return Future.wait(fs).then((_) => id);
    });
  }
  
  
  Future<KeyValuePair<Identifyable, Identifyable>>
  _savePair(DatabaseAdapter adapter, KeyValuePair pair, {bool deep: false}) {
    var fs = [];
    var key, value;
    fs.add(_saveSingle(adapter, pair.key, deep: deep)
        .then((ident) => key = ident));
    fs.add(_saveSingle(adapter, pair.value, deep: deep)
        .then((ident) => value = ident));
    return Future.wait(fs).then((_) => new KeyValuePair(key, value));
  }
  
  Future<Identifyable> _saveSingle(DatabaseAdapter adapter, element, {bool deep: false}) {
    var schema = index.schemaFor(element.runtimeType) as StrongSchema;
    if (!deep) { // If non deep, check for models to be saved
      if (element is Model) {
        if (element.id == null) // Non-Persisted model
          throw "No non-Deep save for unsaved model"; // means an error if non-deep
        return (new Future.value(element)); // No saving or updating for models
      }
      return schema.save(element, deep: deep); // Primitive values ar saved
    }
    return schema.save(element, deep: deep); // If deep, always save(persisted ones will be updated)
  }
  
  Future delete(int id, {bool deep: false}) => index.getAdapter().then((adapter) {
    if (!deep) return _deleteMapLink(adapter, id);
    return adapter.where(str(name), {"id": id}).then((rows) =>
        rows.map((row) => _deleteRow(adapter, row, deep: deep).then((_) =>
            _deleteMapLink(adapter, id))));
  });
  
  Future _deleteRow(DatabaseAdapter adapter, Map<String, dynamic> row, {bool deep: false}) {
    var fs = []; // TODO: Should the model be recreated for lifecycle methods?
    var keySchema = index.schemaFor(row["keyTable"]);
    var valueSchema = index.schemaFor(row["valueTable"]);
    fs.add(keySchema.delete(row["keyId"], deep: deep));
    fs.add(valueSchema.delete(row["valueId"], deep: deep));
    return Future.wait(fs);
  }
  
  Future _deleteMapLink(DatabaseAdapter adapter, int id) {
    return adapter.delete(str(name), {"id": id});
  }
  
  Future drop() =>
      index.getAdapter().then((adapter) => adapter.dropTable(str(name)));
  
  final bool needsPersistance = true;
}


class KeyValuePair<K, V> {
  final K key;
  final V value;
  
  KeyValuePair(this.key, this.value);
  
  static List<KeyValuePair> flattenMap(Map map) {
    return $(map).flatten((key, value) => new KeyValuePair(key, value));
  }
  
  static Map mapFromKeyValues(Iterable<KeyValuePair> keyValues) {
    var result = {};
    keyValues.forEach((kvp) => result[kvp.key] = kvp.value);
    return result;
  }
}