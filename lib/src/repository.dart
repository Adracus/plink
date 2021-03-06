part of plink;

const ignore = const Object();


class ModelRepository {
  final Migrator migrator;
  final SchemaIndex index;
  
  ModelRepository(this.migrator, this.index) {
    migrator.migrate(index);
  }
  
  
  factory ModelRepository.global(DatabaseAdapter adapter) {
    var classes = $.rootLibrary.getClasses(recursive: true).values;
    var candidates = classes.where(isModelSchemaCandidate);
    var migrator = new Migrator(adapter);
    var index = new SchemaIndex(candidates, migrator);
    return new ModelRepository(migrator, index);
  }
  
  
  static bool isModelSchemaCandidate(ClassMirror clazz) {
    return !clazz.isAbstract && !shouldBeIgnored(clazz) &&
        clazz.isSubtypeOf(reflectType(Model));
  }
  
  
  static bool shouldBeIgnored(ClassMirror clazz) {
    return clazz.metadata.map((meta) => meta.reflectee).contains(ignore);
  }
  
  
  Future<List<Model>> where(Type type, s.WhereStatement statement) =>
      index.modelSchemaFor(type).where(statement);
  
  
  Future<Model> save(Model model, {bool deep: false}) =>
      index.modelSchemaFor(model).save(model, deep: deep);
  
  
  Future<List<Model>> saveMany(List<Model> models, {bool deep: false}) =>
      Future.wait(models.map((model) => save(model, deep: deep)));
  
  Future delete(Model model, {bool deep: false}) =>
      index.modelSchemaFor(model).deleteModel(model, deep: deep);
  
  Future deleteMany(List<Model> models, {bool deep: false}) =>
      Future.wait(models.map((model) => delete(model, deep: deep)));
  
  Future<Model> find(Type type, int id) =>
      index.modelSchemaFor(type).find(id);
  
  Future<List<Model>> findMany(Type type, List<int> ids) =>
      Future.wait(ids.map((id) => find(type, id)));
  
  Future<List<Model>> all(Type type) =>
      index.modelSchemaFor(type).all();
}