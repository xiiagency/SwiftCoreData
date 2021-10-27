import CoreData

/**
 Creates and returns a fetch request for the requested model type.
 
 Optionally sets the various components of the fetch in a single go:
 - predicate
 - sort specification
 - fetch offset and limit
 */
public func createFetchRequest<Target : NSManagedObject>(
  _ type: Target.Type,
  predicate: NSPredicate? = nil,
  sort: [NSSortDescriptor]? = nil,
  offset: Int? = nil,
  limit: Int? = nil
) -> NSFetchRequest<Target> {
  // NOTE: We cannot use the default `fetchRequest` implementation in `NSManagedObject` due
  //       to it retrieving records from both the core store and the iCloud synched cache.
  //       This means that after a single record is inserted it shows up as two records after.
  //       Instead we manually construct a fetch request by entity name, similar to how the
  let request = NSFetchRequest<Target>(entityName: String(describing: type))
  
  // NOTE: Even though most of the fetch fields are optionals, we do not know what the effect
  //       is of assigning a nil an extra time. Instead we will only assign the field if we
  //       have a non nil parameter to the fetch/count/delete functions.
  if let predicate = predicate {
    request.predicate = predicate
  }
  
  if let sort = sort {
    request.sortDescriptors = sort
  }
  
  if let offset = offset {
    request.fetchOffset = offset
  }
  
  if let limit = limit {
    request.fetchLimit = limit
  }
  
  return request
}
