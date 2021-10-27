import CoreData
import SwiftUI

/**
 Defines a provider that can return the correct `NSManagedObjectContext` for reading `NSManagedObject`
 records of a specific type.
 
 This is required when using the storage property wrappers (`@StorageRecords`, `@StorageRecord`,
 `@StorageOptionalRecord`) and the application has multiple `NSManagedObjectContext`s.
 */
public protocol ManagedObjectContextProvider {
  /**
   Returns an `NSManagedObjectContext` to use for reading `NSManagedObject` records of a specific type.
   */
  func viewContext<Target : NSManagedObject>(
    for type: Target.Type
  ) throws -> NSManagedObjectContext
}

/**
 The default implementation of `ManagedObjectContextProvider`, using the `managedObjectContext`
 `EnvironmentKey` to retrieve a `NSManagedObjectContext` for any `NSManagedObject` type.
 */
public struct DefaultManagedObjectContextProvider : ManagedObjectContextProvider {
  /**
   Returns the `NSManagedContext` tagged in the `Environment` under the `managedObjectContext` key.
   */
  public func viewContext<Target : NSManagedObject>(
    for type: Target.Type
  ) throws -> NSManagedObjectContext {
    Environment.init(\.managedObjectContext).wrappedValue
  }
}

/**
 The `EnvironmentKey` used to read/write the `managedObjectContextProvider` value from `EnvironmentValues`.
 */
private struct ManagedObjectContextProviderKey : EnvironmentKey {
  /**
   Uses an instance of `DefaultManagedObjectContextProvider` as the default value.
   */
  static let defaultValue: ManagedObjectContextProvider = DefaultManagedObjectContextProvider()
}

extension EnvironmentValues {
  /**
   Allows access to a `ManagedObjectContextProvider` or the default one if no specific one was registered.
   */
  public var managedObjectContextProvider: ManagedObjectContextProvider {
    get { self[ManagedObjectContextProviderKey.self] }
    set { self[ManagedObjectContextProviderKey.self] = newValue }
  }
}

extension View {
  /**
   Registers a specific `ManagedObjectContextProvider` with the `Environment`.
   */
  public func managedObjectContextProvider(_ provider: ManagedObjectContextProvider) -> some View {
    environment(\.managedObjectContextProvider, provider)
  }
}
