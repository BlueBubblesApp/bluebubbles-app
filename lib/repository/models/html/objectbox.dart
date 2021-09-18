export 'package:objectbox/src/box.dart' hide InternalBoxAccess;
import 'package:objectbox/src/transaction.dart';

/// Box put (write) mode.
enum PutMode {
  /// Insert (if given object's ID is zero) or update an existing object.
  put,

  /// Insert a new object.
  insert,

  /// Update an existing object, fails if the given ID doesn't exist.
  update,
}

class QueryBuilder<T> {}

abstract class Condition<EntityT> {}

class Box<T> {

  /// Puts the given Object in the box (aka persisting it).
  ///
  /// If this is a new object (its ID property is 0), a new ID will be assigned
  /// to the object (and returned).
  ///
  /// If the object with given was already in the box, it will be overwritten.
  ///
  /// Performance note: consider [putMany] to put several objects at once.
  int put(T object, {PutMode mode = PutMode.put}) => throw Exception('Unsupported Platform');

  /// Puts the given object in the box (persisting it) asynchronously.
  ///
  /// The returned future completes with an ID of the object. If it is a new
  /// object (its ID property is 0), a new ID will be assigned to the object
  /// argument, after the returned [Future] completes.
  ///
  /// In extreme scenarios (e.g. having hundreds of thousands async operations
  /// per second), this may fail as internal queues fill up if the disk can't
  /// keep up. However, this should not be a concern for typical apps.
  /// The returned future may also complete with an error if the put failed
  /// for another reason, for example a unique constraint violation. In that
  /// case the [object]'s id field remains unchanged (0 if it was a new object).
  ///
  /// See also [putQueued] which doesn't return a [Future] but a pre-allocated
  /// ID immediately, even though the actual database put operation may fail.
  Future<int> putAsync(T object, {PutMode mode = PutMode.put}) async => throw Exception('Unsupported Platform');

  /// Schedules the given object to be put later on, by an asynchronous queue.
  ///
  /// The actual database put operation may fail even if this function returned
  /// normally (and even if it returned a new ID for a new object). For example
  /// if the database put failed because of a unique constraint violation.
  /// Therefore, you should make sure the data you put is correct and you have
  /// a fall back in place even if it eventually failed.
  ///
  /// In extreme scenarios (e.g. having hundreds of thousands async operations
  /// per second), this may fail as internal queues fill up if the disk can't
  /// keep up. However, this should not be a concern for typical apps.
  ///
  /// See also [putAsync] which returns a [Future] that only completes after an
  /// actual database put was successful.
  /// Use [Store.awaitAsyncCompletion] and [Store.awaitAsyncSubmitted] to wait
  /// until all operations have finished.
  int putQueued(T object, {PutMode mode = PutMode.put}) => throw Exception('Unsupported Platform');

  /// Puts the given [objects] into this Box in a single transaction.
  ///
  /// Returns a list of all IDs of the inserted Objects.
  List<int> putMany(List<T> objects, {PutMode mode = PutMode.put}) => throw Exception('Unsupported Platform');

  /// Retrieves the stored object with the ID [id] from this box's database.
  /// Returns null if an object with the given ID doesn't exist.
  T? get(int id) => throw Exception('Unsupported Platform');

  /// Returns a list of [ids.length] Objects of type T, each corresponding to
  /// the location of its ID in [ids]. Non-existent IDs become null.
  ///
  /// Pass growableResult: true for the resulting list to be growable.
  List<T?> getMany(List<int> ids, {bool growableResult = false}) => throw Exception('Unsupported Platform');

  /// Returns all stored objects in this Box.
  List<T> getAll() => throw Exception('Unsupported Platform');

  /// Returns a builder to create queries for Object matching supplied criteria.
  @pragma('vm:prefer-inline')
  QueryBuilder<T> query([Condition<T>? qc]) => throw Exception('Unsupported Platform');

  /// Returns the count of all stored Objects in this box.
  /// If [limit] is not zero, stops counting at the given limit.
  int count({int limit = 0}) => throw Exception('Unsupported Platform');

  /// Returns true if no objects are in this box.
  bool isEmpty() => throw Exception('Unsupported Platform');

  /// Returns true if this box contains an Object with the ID [id].
  bool contains(int id) => throw Exception('Unsupported Platform');

  /// Returns true if this box contains objects with all of the given [ids].
  bool containsMany(List<int> ids) => throw Exception('Unsupported Platform');

  /// Removes (deletes) the Object with the given [id]. Returns true if the
  /// object was present (and thus removed), otherwise returns false.
  bool remove(int id) => throw Exception('Unsupported Platform');

  /// Removes (deletes) by ID, returning a list of IDs of all removed Objects.
  int removeMany(List<int> ids) => throw Exception('Unsupported Platform');

  /// Removes (deletes) ALL Objects in a single transaction.
  int removeAll() => throw Exception('Unsupported Platform');
}

class Store {
  Box<T> box<T>() => throw Exception('Unsupported Platform');

  R runInTransaction<R>(TxMode mode, R Function() fn) => throw Exception('Unsupported Platform');
}

Future<Store> openStore(
    {String? directory,
      int? maxDBSizeInKB,
      int? fileMode,
      int? maxReaders,
      bool queriesCaseSensitiveDefault = true,
      String? macosApplicationGroup}) async => throw Exception('Unsupported Platform');