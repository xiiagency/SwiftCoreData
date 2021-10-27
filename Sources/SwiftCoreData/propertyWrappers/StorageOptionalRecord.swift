import CoreData
import SwiftFoundationExtensions
import SwiftUI
import os

/**
 Provides access to the results of an `NSFetchRequest` for the `Target` type.
 
 The result is assumed to be a single managed record. If more than one record is found, and error is raised.
 If zero records are found, the result will be nil.
 
 Similar to `@FetchRequest` but processes the fetch via `ManagedObjectContextProvider` available in the
 view's environment. This allows for supporting multiple contexts for an application and routing read operations to specific
 context instances.
 
 Example:
   ```
   @StorageOptionalRecord(
     fetchRequest: ...
   ) private var record: MyManagedObjectType?
   ```
 */
@propertyWrapper
public struct StorageOptionalRecord<Target : NSManagedObject> : DynamicProperty {
  private let logger: Logger = .loggerFor(StorageOptionalRecord.self)
  
  /**
   The fetch request used to retrieve the requested records.
   */
  private let fetchRequest: NSFetchRequest<Target>
  
  /**
   Provides a way to retrieve an `NSManagedObjectContext` for the type being fetched.
   */
  @Environment(\.managedObjectContextProvider) private var contextProvider
  
  /**
   Controls the flow of retrieving records and responding to store updates.
   */
  @StateObject private var controller = StorageRecordsController<Target>()
  
  /**
   Initializes the wrapper with a `NSFetchRequest`.
   */
  public init(_ fetchRequest: NSFetchRequest<Target>) {
    self.fetchRequest = fetchRequest
  }
  
  public var wrappedValue: Target? {
    get {
      do {
        return try controller.optionalSingle()
      } catch {
        fatalError("Failed to retrieve results: \(error.description)")
      }
    }
    nonmutating set {
      logger.warning("Cannot set value of StorageOptionalRecord wrapper: \(String(describing: newValue))")
    }
  }
  
  /**
   Called before a view's body is rendered to update our `wrappedValue`.
   Initializes the underlying controller, executing the requested fetch and starts to monitor the store for changes.
   */
  nonmutating public func update() {
    do {
      let context = try contextProvider.viewContext(for: Target.self)
      try controller.initialize(for: fetchRequest, using: context)
    } catch {
      fatalError("Failed to update StorageOptionalRecord wrapper during update: \(error.description)")
    }
  }
}
