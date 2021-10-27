import CoreData
import SwiftFoundationExtensions
import SwiftUI
import os

/**
 Provides access to the results of an `NSFetchRequest` for the `Target` type.
 
 The result is assumed to be a single managed record. If more than one record is found, or zero, and error is raised.
 
 Similar to `@FetchRequest` but processes the fetch via `ManagedObjectContextProvider` available in the
 view's environment. This allows for supporting multiple contexts for an application and routing read operations to specific
 context instances.
 
 Example:
   ```
   @StorageRecord(
     fetchRequest: ...
   ) private var record: MyManagedObjectType
   ```
 */
@propertyWrapper
public struct StorageRecord<Target : NSManagedObject> : DynamicProperty {
  private let logger: Logger = .loggerFor(StorageRecord.self)
  
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
  
  public var wrappedValue: Target {
    get {
      do {
        return try controller.single()
      } catch {
        fatalError("Failed to retrieve results: \(error.description)")
      }
    }
    nonmutating set {
      logger.warning("Cannot set value of StorageRecord wrapper: \(String(describing: newValue))")
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
      fatalError("Failed to update StorageRecord wrapper during update: \(error.description)")
    }
  }
  
  /**
   A wrapper of the underlying record that can create `Binding`s to its properties using dynamic member lookup.
   */
  @dynamicMemberLookup
  public struct Wrapper {
    // Reference to the record.
    unowned private let record: Target
    
    init(_ record: Target) {
      self.record = record
    }
    
    /**
     Retrieves a property of the record as a `Binding`.
     */
    public subscript<Value>(
      dynamicMember keyPath: ReferenceWritableKeyPath<Target, Value>
    ) -> Binding<Value> {
      Binding(
        get: {
          record[keyPath: keyPath]
        },
        set: { newValue in
          record[keyPath: keyPath] = newValue
        }
      )
    }
  }
  
  /**
   A projection of the observed object that creates `Binding`s to its properties using dynamic member lookup.
   
   Use the projected value to pass a binding value down a view hierarchy.
   To get the `projectedValue`, prefix the property variable with `$`.
   */
  public var projectedValue: StorageRecord<Target>.Wrapper {
    Wrapper(wrappedValue)
  }
}
