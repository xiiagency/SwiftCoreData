import CoreData
import SwiftConcurrency
import SwiftFoundationExtensions
import os

extension NSPersistentCloudKitContainer {
  /**
   Used for logging informational messages.
   */
  private static let logger: Logger = .loggerFor(NSPersistentCloudKitContainer.self)
  
  /**
   Creates a `NSPersistentCloudKitContainer` with a specific name (matching the models file) and a set of
   `NSPersistentStore`s to be created from their individual `CoreDataStoreConfiguration`.
   
   - Parameter name: The name of the container, matching its models definition file.
   - Parameter stores: List of `CoreDataStoreConfigurations`, describing the `NSPersistentStore`s for the container.
   */
  public static func create(
    name: String,
    stores: [CoreDataStoreConfiguration]
  ) async throws -> NSPersistentCloudKitContainer {
    // Create the container with the requested name.
    let container = NSPersistentCloudKitContainer(name: name)
    
    // Create all requested stores from their configurations.
    let storeDescriptions = stores.map { configuration in configuration.storeDescription }
    
    // Set the store as the backing store of the container.
    container.persistentStoreDescriptions = storeDescriptions
    
    // Prepare the container by loading its stores.
    try await container.loadPersistentStores()
    
    // Set up main context's options, after the store has been initialized.
    try await container.setupViewContext()
    
    return container
  }
  
  /**
   Initializes the database schema in iCloud for the `NSPersistentCloudKitContainer`.
   
   In order to be able to initialize a cloud schema:
   - The type of all stores in the container need to be `NSSQLiteStoreType`
   - The database scope used must be `CKDatabase.Scope.private` (see below how to initialize a public schema)
   
   The cloud database schema should be initialized whenever the models have changed by calling this function from a debug build
   at start up.
   
   NOTE: iCloud sync will not be active for the session that has initialized the schema.
   
   NOTE: Initializing the cloud database schema for a publicly scoped store  should only be done when initially creating the public schema
   OR when it has changed. Take special care if you get an error when initializing due to missing CDMR records.
   Creating a fake many-to-many relationship when initializing can help resolve these.
   
   NOTE: Transient store types within the container need to be excluded from the container during schema initializations
   or schema creation will fail.
   */
  public func initializeContainerCloudKitSchema() throws {
    try initializeCloudKitSchema(options: [])
  }
  
  /**
   Waits for event notifications from the given container that it has completed its initial cloud kit import.
   Polls the container event stream at a given interval and waits for a maximum of the requested timeout time for the sync to complete.
   
   NOTE: The import being complete does not mean that data has been fully downloaded from CloudKit, since the user may be offline.
   */
  public func waitForInitialCloudKitImport(
    pollIntervalSeconds: Double,
    pollTimeoutSeconds: Double
  ) async throws {
    // Log the fact that we started waiting.
    Self.logger.info("Waiting for initial CloudKit import for: \(self.name, privacy: .public)")
    
    // Make sure that we only process the container's stores that are linked to iCloud.
    let affectedStores = persistentStoreDescriptions
      .filter { description in description.cloudKitContainerOptions != nil }
      .map { description in
        persistentStoreCoordinator.persistentStore(for: description.url!)!
      }
    
    // Grab all events from the beginning of time.
    let request = NSPersistentCloudKitContainerEventRequest.fetchEvents(after: .distantPast)
    request.resultType = .events
    request.affectedStores = affectedStores
    
    // Initial delay to allow SQLite to propagate initialization if needed.
    // NOTE: Needed since we are querying for events from the container and that table needs
    //       to have been created first.
    try await Task.sleep(seconds: pollIntervalSeconds)
    
    // Poll for events, checking import status.
    // NOTE: Task closure is executed on the main actor so that it can have access to the
    //       `viewContext` of the container.
    let isSyncCompleted = try await Task.poll(
      intervalSeconds: pollIntervalSeconds,
      timeoutSeconds: pollTimeoutSeconds
    ) { @MainActor [self] in
      // Go through all events and see if there is an import completion.
      let results: NSPersistentStoreResult = try viewContext.execute(request)
      if let results = results as? NSPersistentCloudKitContainerEventResult,
         let events = results.result as? [NSPersistentCloudKitContainer.Event] {
        
        // Check for store import event that is successful.
        return events.contains(where: { event in event.succeeded && event.type == .import })
      }
      
      // If we can't interpret results, keep polling.
      return false
    }
    
    // If we weren't canceled, detect and log success or timeout.
    if !Task.isCancelled {
      if isSyncCompleted {
        Self.logger.info("Initial CloudKit import succeeded for: \(self.name, privacy: .public)")
      } else {
        Self.logger.info("Initial CloudKit import timed out for: \(self.name, privacy: .public)")
      }
    }
  }
}
