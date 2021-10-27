import CoreData
import SwiftFoundationExtensions
import os

/**
 Fetch controller used in the storage properties wrappers (`StorageRecords`/`StorageRecord`/`StorageOptionalRecord`).
 Implements the common logic to perform the initial fetch as well as to monitor storage for any updates of the affected records.
 */
class StorageRecordsController<Target : NSManagedObject> :
  NSObject, ObservableObject, NSFetchedResultsControllerDelegate {
  
  private let logger: Logger = .loggerFor(StorageRecordsController.self)
  
  /**
   Flag of whether the controller has been initialized and the initial fetch was performed.
   */
  @Published private(set) var initialized: Bool = false
  
  /**
   The current set of results of the fetch.
   */
  @Published private(set) var results: [Target] = []
  
  /**
   Used to perform the fetch and monitor storage for any changes in the affected records.
   */
  private var fetchController: NSFetchedResultsController<Target>? = nil
  
  deinit {
    // Make sure to unlink from the controller so that we get de-initialized correctly.
    fetchController?.delegate = nil
  }
  
  /**
   Initializes the controller for a specific fetch request, performs the initial fetch, and begins monitoring the storage for any changes
   in the affected records.
   */
  func initialize(
    for fetchRequest: NSFetchRequest<Target>,
    using viewContext: NSManagedObjectContext
  ) throws {
    // Make sure we only initialize once.
    guard !initialized else {
      return
    }
    
    initialized = true
    
    // NOTE: NSFetchResultController requires at least one sort due to its implementation.
    //       If none was specified by the caller, add a default sort by ID.
    if fetchRequest.sortDescriptors == nil {
      fetchRequest.sortDescriptors = [NSSortDescriptor(key: "objectID", ascending: true)]
    }
    
    // Create the fetch controller.
    let fetchController = NSFetchedResultsController(
      fetchRequest: fetchRequest,
      managedObjectContext: viewContext,
      sectionNameKeyPath: nil,
      cacheName: nil
    )
    
    // Set ourselves as a delegate to monitor changes and retain the controller instance.
    fetchController.delegate = self
    self.fetchController = fetchController
    
    // Execute the initial fetch, synchronously.
    try fetchController.performFetch()
    
    // Grab all results from the initial fetch and update our state.
    if let results = fetchController.fetchedObjects {
      self.results = results
    }
  }
  
  /**
   Called every time after pending changes in storage are done and there are changes that affect our fetch request.
   */
  func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    do {
      // Force refresh the controller's contents.
      // NOTE: This is required due to the update sometimes causing the fetchedObject to contain
      //       duplicates. Refetching seems to solve this issue.
      try controller.performFetch()
      
      // Grab the latest results from the controller on each change.
      if let results = controller.fetchedObjects as? [Target] {
        self.results = results
      }
    } catch {
      logger.error("Failed to retrieve updated fetch results: \(error.description, privacy: .public)")
    }
  }
  
  /**
   Convenience function for callers that expect exactly one result from the fetch.
   Ensures that there is exactly 1 result and returns it.
   */
  func single() throws -> Target {
    guard results.count == 1,
          let result = results.first else {
            throw CoreDataError.InvalidNumberOfResults(expected: 1, actual: results.count).withTrace()
          }
    
    return result
  }
  
  /**
   Convenience function for callers that expect either zero or exactly one result from the fetch.
   Ensures that there is at most one result and returns it, or nil if no matching records in storage exist.
   */
  func optionalSingle() throws -> Target? {
    guard results.count <= 1 else {
      throw CoreDataError.InvalidNumberOfResults(expected: 1, actual: results.count).withTrace()
    }
    
    return results.first
  }
}
