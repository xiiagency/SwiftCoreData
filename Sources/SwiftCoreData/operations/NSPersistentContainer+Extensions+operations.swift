import CoreData

extension NSPersistentContainer {
  /**
   Returns the store with the requested `URL` (if provided and found) or the single used store within the current container
   (if no url is specified AND the container contains only a single store).
   */
  public func store(for storeUrl: URL?) throws -> NSPersistentStore {
    // Make sure we can access the coordinator.
    guard let coordinator = viewContext.persistentStoreCoordinator else {
      throw CoreDataError.StoreNotFound(storeUrl: storeUrl).withTrace()
    }
    
    // If no specific URL was specified and the coordinator has just one store, return it.
    if coordinator.persistentStores.count == 1 && storeUrl == nil,
       let store = coordinator.persistentStores.first {
      return store
    }
    
    // Otherwise, attempt to find the store with the requested URL.
    if let storeUrl = storeUrl,
       let store = coordinator.persistentStore(for: storeUrl) {
      return store
    }
    
    // If the find operation failed, raise an error.
    throw CoreDataError.StoreNotFound(storeUrl: storeUrl).withTrace()
  }
  
  /**
   Returns a new instance (non populated) of the requested `NSManagedObject` type, connected to the `viewContext`.
   Optionally, can specify if the record should be assigned to a store of a specific type within the container
   (e.g. in memory store used for transient records).
   
   NOTE: Since this interacts with the `viewContext` of the container and should be performed on main.
   */
  public func newRecord<Target : NSManagedObject>(
    _ type: Target.Type,
    storeUrl: URL?
  ) throws -> Target {
    // Create the record in the view context.
    let record = Target(context: viewContext)
    
    // Assign the record to the correct store, by url.
    let store = try store(for: storeUrl)
    viewContext.assign(record, to: store)
    
    // Return the record, ready to have its fields populated.
    return record
  }
  
  /**
   Saves any changes in the container's `viewContext` to its backing store.
   Returns true if there were changes to save and the operation succeeds, false if there were no changes.
   
   NOTE: Since this interacts with the `viewContext` of the container and should be performed on main.
   */
  @discardableResult
  public func flushChanges() throws -> Bool {
    // If there are no changes, there isn't anything to do.
    guard viewContext.hasChanges else {
      return false
    }
    
    // Otherwise, flush all changes and return.
    try viewContext.save()
    return true
  }
  
  /**
   Removes all records that match the the provided `NSFetchRequest` via a `NSBatchDeleteRequest`.
   
   NOTE: Applies only to persistent (non transient) records within the container's `NSSQLiteStoreType`.
   
   NOTE: This operation does not automatically flush changes, but rather performs the delete on the backing store and then syncs
   it with the memory store.
   
   NOTE: Since this interacts with the `viewContext` of the container and should be performed on main.
   */
  public func delete<Target : NSManagedObject>(
    _ request: NSFetchRequest<Target>,
    storeUrl: URL?
  ) throws {
    // Find the store responsible for the persistent records.
    let store = try store(for: storeUrl)
    
    // Define the fetch request and batch delete operation.
    let batchDelete = NSBatchDeleteRequest(
      fetchRequest: request as! NSFetchRequest<NSFetchRequestResult>
    )
    batchDelete.resultType = .resultTypeObjectIDs
    
    // NOTE: Target only the sqlite store since issuing a batch delete to the in-memory transient
    //       stores will result in errors.
    batchDelete.affectedStores = [store]
    
    // Execute the delete, returning the set of IDs removed.
    let results = try viewContext.execute(batchDelete)
    
    // The batch delete operation above operates on the stored version of the store, the container
    // still holds the removed objects (if they were loaded). Ensure we merge the changes for
    // these IDs between the memory and persistent state.
    if let deletedIds = (results as? NSBatchDeleteResult)?.result as? [NSManagedObjectID] {
      let changes = [NSDeletedObjectsKey: deletedIds]
      NSManagedObjectContext.mergeChanges(
        fromRemoteContextSave: changes,
        into: [viewContext]
      )
    }
  }
}
