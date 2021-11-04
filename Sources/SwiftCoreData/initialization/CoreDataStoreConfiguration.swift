import CoreData
import CloudKit

/**
 Describes the configuration of a `NSPersistentStore` as described by `NSPersistentStoreDescription`.
 */
public enum CoreDataStoreConfiguration {
  /**
   A SQLite backed local stored that has iCloud sync enabled.
   
   - Parameter sqliteName: The name of the sqlite file (not the full path).
   - Parameter cloudContainerId: The ID of the iCloud container that the store syncs to.
   - Parameter cloudContainerScope: The database scope of the synched iCloud container (e.g. public/private/shared).
   - Parameter configurationName: The model configuration name to use, if any.
   */
  case CloudSynchedSqliteStore(
    sqliteName: String,
    cloudContainerId: String,
    cloudContainerScope: CKDatabase.Scope,
    configurationName: String?
  )
  
  /**
   An in-memory transient store that can be used to manage objects that only exist for the lifecycle of the app process.
   
   - Parameter configurationName: The model configuration name to use, if any.
   */
  case TransientInMemoryStore(configurationName: String?)
  
  /**
   A local SQLite store that is not connected to iCloud.
   
   - Parameter sqliteName: The name of the sqlite file (not the full path).
   - Parameter configurationName: The model configuration name to use, if any.
   */
  case LocalSqliteStore(
    sqliteName: String,
    configurationName: String?
  )
  
  /**
   Returns the full `URL` of the store, based on it's type and description.
   */
  public var storeUrl: URL {
    switch self {
    case let .CloudSynchedSqliteStore(sqliteName, _, _, _),
         let .LocalSqliteStore(sqliteName, _):
      return NSPersistentContainer.defaultDirectoryURL().appendingPathComponent(sqliteName)
      
    case .TransientInMemoryStore:
      return URL(fileURLWithPath: "/dev/null")
    }
  }
  
  /**
   Returns an `NSPersistentStoreDescription` for a specific `CoreDataStoreConfiguration`.
   */
  var storeDescription: NSPersistentStoreDescription {
    switch self {
    case let .CloudSynchedSqliteStore(_, cloudContainerId, cloudContainerScope, configurationName):
      return getCloudSynchedSqliteStoreDescription(
        storeUrl: storeUrl,
        cloudContainerId: cloudContainerId,
        cloudContainerScope: cloudContainerScope,
        configurationName: configurationName
      )
      
    case let .TransientInMemoryStore(configurationName):
      return getTransientInMemoryStoreDescription(
        storeUrl: storeUrl,
        configurationName: configurationName
      )
    
    case let .LocalSqliteStore(_, configurationName):
      return getLocalSqliteStoreDescription(
        storeUrl: storeUrl,
        configurationName: configurationName
      )
    
    }
  }
  
  /**
   Returns an `NSPersistentStoreDescription` for the specifications of a SQLite local store that also syncs to iCloud.
   
   - Parameter storeUrl: The local URL of the store.
   - Parameter cloudContainerId: The ID of the iCloud container that the store syncs to.
   - Parameter cloudContainerScope: The database scope of the synched iCloud container (e.g. public/private/shared).
   - Parameter configurationName: The model configuration name to use, if any.
   */
  private func getCloudSynchedSqliteStoreDescription(
    storeUrl: URL,
    cloudContainerId: String,
    cloudContainerScope: CKDatabase.Scope,
    configurationName: String?
  ) -> NSPersistentStoreDescription {
    // Configure the local portion of the store first.
    let store = getLocalSqliteStoreDescription(
      storeUrl: storeUrl,
      configurationName: configurationName
    )
    
    // Set up iCloud mirroring.
    let cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
      containerIdentifier: cloudContainerId
    )
    cloudKitContainerOptions.databaseScope = cloudContainerScope
    store.cloudKitContainerOptions = cloudKitContainerOptions
    
    return store
  }
  
  /**
   Returns an `NSPersistentStoreDescription` for the specifications of an in-memory transient local store.
   
   - Parameter storeUrl: The local URL of the store.
   - Parameter configurationName: The model configuration name to use, if any.
   */
  private func getTransientInMemoryStoreDescription(
    storeUrl: URL,
    configurationName: String?
  ) -> NSPersistentStoreDescription {
    let transientStore = NSPersistentStoreDescription(url: storeUrl)
    transientStore.type = NSInMemoryStoreType
    transientStore.configuration = configurationName
    
    return transientStore
  }
  
  /**
   Returns an `NSPersistentStoreDescription` for the specifications of a SQLite local store WITHOUT iCloud sync.
   
   - Parameter storeUrl: The local URL of the store.
   - Parameter configurationName: The model configuration name to use, if any.
   */
  private func getLocalSqliteStoreDescription(
    storeUrl: URL,
    configurationName: String?
  ) -> NSPersistentStoreDescription {
    // Initialize the store.
    let store = NSPersistentStoreDescription(url: storeUrl)
    
    // Make it a SQLite store with tracking and remote change notifications.
    store.type = NSSQLiteStoreType
    store.configuration = configurationName
    store.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
    store.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
    
    return store
  }
}
