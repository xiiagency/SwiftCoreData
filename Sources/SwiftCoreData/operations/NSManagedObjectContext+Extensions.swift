import CoreData

extension NSManagedObjectContext {
  /**
   Fetches a single record using the provided `NSFetchRequest`.
   It is assumed that the fetch limit in the request is configured correctly and an error is thrown if there is more than one record read.
   */
  public func fetchSingle<Target : NSManagedObject>(_ request: NSFetchRequest<Target>) throws -> Target {
    let candidates = try fetch(request)
    guard candidates.count == 1, let result = candidates.first else {
      throw CoreDataError.InvalidNumberOfResults(expected: 1, actual: candidates.count)
    }
    
    return result
  }
}
