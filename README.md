# SwiftCoreData Library

[![GitHub](https://img.shields.io/github/license/xiiagency/SwiftCoreData?style=for-the-badge)](./LICENSE)

An open source library that includes utilities and extensions to help work with `CoreData`.

Developed as re-usable components for various projects at
[XII's](https://github.com/xiiagency) iOS, macOS, and watchOS applications.

## Installation

### Swift Package Manager

1. In Xcode, select File > Swift Packages > Add Package Dependency.
2. Follow the prompts using the URL for this repository
3. Select the `SwiftCoreData` library to add to your project

## Dependencies

- [xiiagency/SwiftFoundationExtensions](https://github.com/xiiagency/SwiftFoundationExtensions)
- [xiiagency/SwiftConcurrency](https://github.com/xiiagency/SwiftConcurrency)

## License

See the [LICENSE](LICENSE) file.

## Defining `CoreData` stores ([Source](Sources/SwiftCoreData/initialization/CoreDataStoreConfiguration.swift))

```Swift
enum CoreDataStoreConfiguration {
  case CloudSynchedSqliteStore(
    sqliteName: String,
    cloudContainerId: String,
    cloudContainerScope: CKDatabase.Scope,
    configurationName: String?
  )

  case TransientInMemoryStore(
    configurationName: String?
  )

  case LocalSqliteStore(
    sqliteName: String,
    configurationName: String?
  )
}
```

Describes the configuration of a `NSPersistentStore` as described by `NSPersistentStoreDescription`.

Includes support for:

- Local SQLite stores
- Cloud synchronized (iCloud container) SQLite stores
- In-memory transient stores

### Extracting the store's `URL`

```Swift
extension CoreDataStoreConfiguration {
  var storeUrl: URL { get }
}
```

Returns the full `URL` of the store, based on it's type and description.

## Creating `NSPersistentContainer`s ([Source](Sources/SwiftCoreData/initialization/NSPersistentContainer%2BExtensions%2Binitialization.swift))

```Swift
extension NSPersistentContainer {
  static func create(
    name: String,
    stores: [CoreDataStoreConfiguration]
  ) async throws -> Self
}
```

Creates a `NSPersistentContainer` with a specific name (matching the models file) and a set of `NSPersistentStore`s to be created from their individual `CoreDataStoreConfiguration`.

**NOTE:** The store descriptions used MUST not have iCloud configured stores.

---

```Swift
extension NSPersistentContainer {
  static func createMockInMemoryContainer(
    name: String
  ) -> NSPersistentContainer
}
```

Support for quick initialiation in previews: Initializes a mock in memory container with the given name.

## Extensions for `NSPersistentCloudKitContainer`s ([Source](Sources/SwiftCoreData/initialization/NSPersistentCloudKitContainer%2BExtensions.swift))

```Swift
extension NSPersistentCloudKitContainer {
  func initializeContainerCloudKitSchema() throws
}
```

Initializes the database schema in iCloud for the `NSPersistentCloudKitContainer`.

In order to be able to initialize a cloud schema:

- The type of all stores in the container need to be `NSSQLiteStoreType`
- The database scope used must be `CKDatabase.Scope.private` (see below how to initialize a public schema)

The cloud database schema should be initialized whenever the models have changed by calling this function from a debug build at start up.

**NOTE:** iCloud sync will not be active for the session that has initialized the schema.

**NOTE:** Initializing the cloud database schema for a publicly scoped store should only be done when initially creating the public schema OR when it has changed. Take special care if you get an error when initializing due to missing CDMR records. Creating a fake many-to-many relationship when initializing can help resolve these.

**NOTE:** Transient store types within the container need to be excluded from the container during schema initializations
or schema creation will fail.

---

```Swift
extension NSPersistentCloudKitContainer {
  func waitForInitialCloudKitImport(
    pollIntervalSeconds: Double,
    pollTimeoutSeconds: Double
  ) async throws
}
```

Waits for event notifications from the given container that it has completed its initial cloud kit import. Polls the container event stream at a given interval and waits for a maximum of the requested timeout time for the sync to complete.

**NOTE:** The import being complete does not mean that data has been fully downloaded from CloudKit, since the user may be offline.

## `NSFetchRequest` creation helper ([Source](Sources/SwiftCoreData/operations/CreateFetchRequest.swift))

```Swift
func createFetchRequest<Target : NSManagedObject>(
  _ type: Target.Type,
  predicate: NSPredicate? = nil,
  sort: [NSSortDescriptor]? = nil,
  offset: Int? = nil,
  limit: Int? = nil
) -> NSFetchRequest<Target>
```

Creates and returns a fetch request for the requested model type.

## Fetch helpers ([Source](Sources/SwiftCoreData/operations/NSManagedObjectContext%2BExtensions.swift))

```Swift
extension NSManagedObjectContext {
  func fetchSingle<Target : NSManagedObject>(
    _ request: NSFetchRequest<Target>
  ) throws -> Target
}
```

Fetches a single record using the provided `NSFetchRequest`.

It is assumed that the fetch limit in the request is configured correctly and an error is thrown if there is more than one record read.

## `NSPersistentContainer` helper extensions ([Source](Sources/SwiftCoreData/operations/NSPersistentContainer%2BExtensions%2Boperations.swift))

```Swift
extension NSPersistentContainer {
  func store(for storeUrl: URL?) throws -> NSPersistentStore
}
```

Returns the store with the requested `URL` (if provided and found) or the single used store within the current container (if no url is specified AND the container contains only a single store).

---

```Swift
extension NSPersistentContainer {
  func newRecord<Target : NSManagedObject>(
    _ type: Target.Type,
    storeUrl: URL?
  ) throws -> Target
}
```

Returns a new instance (non populated) of the requested `NSManagedObject` type, connected to the `viewContext`.

Optionally, can specify if the record should be assigned to a store of a specific type within the container (e.g. in memory store used for transient records).

**NOTE:** Since this interacts with the `viewContext` of the container and should be performed on the main thread.

---

```Swift
extension NSPersistentContainer {
  @discardableResult
  func flushChanges() throws -> Bool
}
```

Saves any changes in the container's `viewContext` to its backing store.

Returns true if there were changes to save and the operation succeeds, false if there were no changes.

**NOTE:** Since this interacts with the `viewContext` of the container and should be performed on the main thread.

---

```Swift
extension NSPersistentContainer {
  func delete<Target : NSManagedObject>(
    _ request: NSFetchRequest<Target>,
    storeUrl: URL?
  ) throws
}
```

Removes all records that match the the provided `NSFetchRequest` via a `NSBatchDeleteRequest`.

**NOTE:** Applies only to persistent (non transient) records within the container's `NSSQLiteStoreType`.

**NOTE:** This operation does not automatically flush changes, but rather performs the delete on the backing store and then syncs it with the memory store.

**NOTE:** Since this interacts with the `viewContext` of the container and should be performed on the main thread.

## Providing a `NSManagedObjectContext` to `View`s ([Source](Sources/SwiftCoreData/propertyWrappers/ManagedObjectContextProvider.swift))

```Swift
protocol ManagedObjectContextProvider {
  func viewContext<Target : NSManagedObject>(
    for type: Target.Type
  ) throws -> NSManagedObjectContext
}
```

Defines a provider that can return the correct `NSManagedObjectContext` for reading `NSManagedObject` records of a specific type.

This is required when using the storage property wrappers (`@StorageRecords`, `@StorageRecord`, `@StorageOptionalRecord`) and the application has multiple `NSManagedObjectContext`s.

---

```Swift
extension View {
  func managedObjectContextProvider(
    _ provider: ManagedObjectContextProvider
  ) -> some View
}
```

Registers a specific `ManagedObjectContextProvider` with the `Environment`.

### Example Usage

```Swift
class CoreDataService : ManagedObjectContextProvider {
  ...

  func viewContext<Target : NSManagedObject>(
    for type: Target.Type
  ) throws -> NSManagedObjectContext {
    ...
  }
}

struct FooView : View {
  @StateObject private var coreDataService = CoreDataService()

  var body : some View {
    ContentView()
      .managedObjectContextProvider(coreDataService)
  }
}
```

## SwiftUI fetch property wraoppers

### Loading multiple records ([Source](Sources/SwiftCoreData/propertyWrappers/StorageRecords.swift))

```Swift
@propertyWrapper
struct StorageRecords<Target : NSManagedObject> : DynamicProperty {
  init(_ fetchRequest: NSFetchRequest<Target>)

  var wrappedValue: [Target] { get }

  nonmutating func update()
}
```

Provides access to the results of an `NSFetchRequest` for the `Target` type.

Similar to `@FetchRequest` but processes the fetch via `ManagedObjectContextProvider` available in the view's environment. This allows for supporting multiple contexts for an application and routing read operations to specific context instances.

Example:

```Swift
struct FooView : View {
  @StorageRecords(
    fetchRequest: ...
  ) private var records: [MyManagedObjectType]

  var body : View {
    Text("Loaded: \(records.count)")
  }
}
```

### Loading a single record ([Source](Sources/SwiftCoreData/propertyWrappers/StorageRecord.swift))

```Swift
@propertyWrapper
public struct StorageRecord<Target : NSManagedObject> : DynamicProperty {
  init(_ fetchRequest: NSFetchRequest<Target>)

  var wrappedValue: Target { get }

  nonmutating func update()

  @dynamicMemberLookup
  public struct Wrapper {
    subscript<Value>(
      dynamicMember keyPath: ReferenceWritableKeyPath<Target, Value>
    ) -> Binding<Value>
  }

  var projectedValue: StorageRecord<Target>.Wrapper
}
```

Provides access to the results of an `NSFetchRequest` for the `Target` type.

The result is assumed to be a single managed record. If more than one record is found, or zero, and error is raised.

Similar to `@FetchRequest` but processes the fetch via `ManagedObjectContextProvider` available in the view's environment. This allows for supporting multiple contexts for an application and routing read operations to specific context instances.

Supports expanded binding for specific record fields.

Example:

```Swift
struct FooView : View {
  @StorageRecord(
    fetchRequest: ...
  ) private var record: MyManagedObjectType

  var body : View {
    Text("Loaded: \(record.myField)")

    SomeSubView(binding: $record.myField)
  }
}
```

### Loading record that may not exist ([Source](Sources/SwiftCoreData/propertyWrappers/StorageOptionalRecord.swift))

```Swift
@propertyWrapper
public struct StorageOptionalRecord<Target : NSManagedObject> : DynamicProperty {
  init(_ fetchRequest: NSFetchRequest<Target>)

  var wrappedValue: Target? { get }

  nonmutating func update()
}
```

Provides access to the results of an `NSFetchRequest` for the `Target` type.

The result is assumed to be a single managed record. If more than one record is found, and error is raised. If zero records are found, the result will be nil.

Similar to `@FetchRequest` but processes the fetch via `ManagedObjectContextProvider` available in the view's environment. This allows for supporting multiple contexts for an application and routing read operations to specific context instances.

Example:

```Swift
struct FooView : View {
  @StorageOptionalRecord(
    fetchRequest: ...
  ) private var record: MyManagedObjectType?

  var body : View {
    Text("Loaded: \(record.myField ?? "N/A")")
  }
}
```

## `NSManagedObject` extensions ([Source](Sources/SwiftCoreData/NSManagedObject%2BExtensions.swift))

```Swift
extension NSManagedObject {
  func get<Target>(_ value: Optional<Target>) -> Target

  func get(_ value: NSNumber?) -> Int?

  func set(_ value: Int?) -> NSNumber?

  func get(_ value: NSNumber?) -> Int

  func set(_ value: Int) -> NSNumber?

  func get(_ value: NSNumber?) -> Double

  func set(_ value: Double) -> NSNumber?

  func get<Target : RawRepresentable>(
    _ value: String?
  ) -> Target where Target.RawValue == String

  func set<Source : RawRepresentable>(
    _ value: Source
  ) -> String? where Source.RawValue == String

  func get<Target : RawRepresentable>(
    _ value: String?
  ) -> Target? where Target.RawValue == String

  func set<Source : RawRepresentable>(
    _ value: Source?
  ) -> String? where Source.RawValue == String

  func get(_ value: String?) -> TimeZone

  func set(_ value: TimeZone) -> String

  func get<Target : NSManagedObject>(_ value: NSSet?) -> [Target]

  func set<Source : NSManagedObject>(_ value: [Source]) -> NSSet?

  func get(_ value: String?) -> URL

  func set(_ value: URL) -> String
}
```

Provides data transformation short-hand for models that want to expose a type for their attributes that is different than the stored type attribute type (e.g. enum value vs stored `String`).

Example:

```Swift
extension SomeNSManagedObjectType {
  var aliasedAttribute: String {
    get { get(storedAttribute) }
    set { storedAttribute = set(newValue) }
  }
}
```
