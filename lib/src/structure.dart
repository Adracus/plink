part of plink;


const Key KEY = const Key();
const AutoIncrement AUTO_INCREMENT = const AutoIncrement();


abstract class Schema<E> {
  Symbol get name;
  SchemaIndex get index;
  
  bool get needsPersistance;

  FieldCombination get fields;

  Future<E> load(int id);
  Future delete(int id);
  Future drop();
}


abstract class WeakSchema<E> implements Schema<E> {
  Future<E> save(int sourceId, E element);
  Future delete(int sourceId);
}


abstract class Identifyable {
  int get id;
}


abstract class StrongSchema<E extends Identifyable> implements Schema<E>{
  Future<E> save(E element);
  Future delete(int id);
}


class FieldCombination {
  final Set<Field> content;

  factory FieldCombination(Iterable<Field> fields) {
    if (fields == null || fields.every((field) => !field.isKeyField))
      throw new ArgumentError("Fields has to contain a key");
    return new FieldCombination._(fields);
  }

  FieldCombination._(Iterable<Field> fields)
      : content = new Set.from(fields);
  
  FieldCombination._empty()
      : content = new Set();
}


class Field {
  final Symbol name;
  final Type type;
  final ConstraintSet constraints;
  Field(this.name, this.type, [Iterable<Constraint> constraints = const []])
      : constraints = new ConstraintSet(constraints);

  bool get isKeyField => constraints.hasKeyConstraint;
}


abstract class Constraint {
}


class Key implements Constraint {
  const Key();
}


class AutoIncrement implements Constraint {
  const AutoIncrement();
}


class ConstraintSet {
  final Set<Constraint> _content;

  ConstraintSet([Iterable<Constraint> constraints = const []])
      : _content = new Set.from(constraints);

  bool get hasKeyConstraint => _content.any((c) => c is Key);
}


class SchemaIndex {
  final Migrator migrator;
  MapperFramework _mappers;
  Set<Schema> _schemes;

  SchemaIndex(Iterable<ClassMirror> classes, this.migrator) {
    _schemes = classes.toSet().map((clazz) =>
        new ModelSchema(clazz, this)).toSet();
    _mappers = new MapperFramework(this);
    migrator.migrate(this);
  }

  ModelSchema getModelSchema(Type type) {
    return _schemes.firstWhere((schema) =>
        schema is ModelSchema && schema.type == type);
  }

  Future<DatabaseAdapter> getAdapter() => migrator.getAdapter();
  
  MapperFramework get mappers => _mappers;
  
  Schema schemaFor(arg) {
    var mapper = mappers.mapperFor(arg, orElse: () => null);
    if (mapper != null) return mapper;
    var name = _toSym(arg);
    return _schemes.firstWhere((schema) => schema.name == name,
        orElse: () => throw "No Schema found for $arg");
  }
  
  static Symbol _toSym(arg) {
    if (arg is String) return new Symbol(arg);
    if (arg is Symbol) return arg;
    if (arg is Type) return reflectType(arg).qualifiedName;
    throw "Unsupported argument $arg";
  }
  
  List<Schema> get allSchemes {
    var result = [];
    result..addAll(_schemes)
          ..addAll(_mappers.mappers)
          ..addAll(_schemes.where((schema) =>
        schema is ModelSchema).map((ModelSchema schema) =>
            schema.relations).fold([], (l1, l2) => l1..addAll(l2)));
    return result;
  }
}


class MapperFramework {
  final List<Mapper> mappers;
  
  MapperFramework(SchemaIndex index)
      : mappers = Mapper.generateMappers(index);
  
  Mapper mapperFor(arg, {Mapper orElse ()}) {
    if (arg is Type)
      return mappers.firstWhere((mapper) =>
          mapper.matches(arg), orElse: orElse);
    if (arg is String)
      return mappers.firstWhere((mapper) =>
          mapper.name == new Symbol(arg), orElse: orElse);
    throw "Unsupported argument $arg";
  }
  
  Future dropMappers() => Future.wait(mappers.map((mapper) => mapper.drop()));
}