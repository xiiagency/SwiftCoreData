import Foundation

/**
 Errors thrown within the provided core data utilities.
 */
public enum CoreDataError : Error {
  /**
   An unexpected number of results were loaded.
   */
  case InvalidNumberOfResults(expected: Int, actual: Int)
  
  /**
   A store with the requested optional `URL` could not be found.
   */
  case StoreNotFound(storeUrl: URL?)
}
