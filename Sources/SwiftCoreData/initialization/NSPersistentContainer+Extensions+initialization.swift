import CoreData

extension NSPersistentContainer {
  
  /**
   Creates a `NSPersistentContainer` with a specific name (matching the models file) and a set of
   `NSPersistentStore`s to be created from their individual `CoreDataStoreConfiguration`.
   
   - Parameter name: The name of the container, matching its models definition file.
   - Parameter stores: List of `CoreDataStoreConfigurations`, describing the `NSPersistentStore`s for the container.
   
   NOTE: The store descriptions used MUST not have iCloud configured stores.
   */
  public static func create(
    name: String,
    stores: [CoreDataStoreConfiguration]
  ) async throws -> Self {
    // Create the container with the requested name.
    let container = Self.init(name: name)
    
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
   PREVIEW SUPPORT: Initializes a mock in memory container with the given name.
   */
  public static func createMockInMemoryContainer(name: String) -> NSPersistentContainer {
    // Create an in memory store description that points to no file.
    let store = NSPersistentStoreDescription(
      url: CoreDataStoreConfiguration.TransientInMemoryStore(configurationName: nil).storeUrl
    )
    store.type = NSInMemoryStoreType
    
    // Set up a simple container with a single in-memory store.
    let container = NSPersistentContainer(name: name)
    container.persistentStoreDescriptions = [store]
    
    // Prepare the store and return.
    container.loadPersistentStores { storeDescription, error in
      if let error = error {
        fatalError("Could not initialize container persistent store: \(error.description)")
      }
    }
    
    return container
  }
  
  /**
   Asynchronously loads the persistent stores of the container, propagating any errors that occur instead of them being fatal.
   */
  public func loadPersistentStores() async throws {
    // Adopt `loadPersistentStores` to async/await via continuation.
    return try await withCheckedThrowingContinuation { continuation in
      // The number of initializations to wait for is the same as the number of stores initialized.
      var initializationsLeft = persistentStoreDescriptions.count
      
      // Trigger async initialization of the stores.
      loadPersistentStores { storeDescription, error in
        // Handle errors during initialization.
        if let error = error {
          continuation.resume(with: .failure(error))
        }
        
        // On success, decrement how many more stores we have left to initialize.
        initializationsLeft -= 1
        
        if initializationsLeft == 0 {
          // All stores are initialized, we are done.
          continuation.resume()
        } else if initializationsLeft < 0 {
          // Over-initialized for some reason, fail fatally.
          fatalError("Received multiple completions for container store initialization")
        }
      }
    }
  }
  
  /**
   Configures the view context of the container on the main thread (via `@MainActor`):
   - set automatic merges from parent to true
   - sets the merge policy to `NSMergeByPropertyObjectTrumpMergePolicy`
   - pins the query generation to current
   */
  @MainActor
  func setupViewContext() throws {
    viewContext.automaticallyMergesChangesFromParent = true
    viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    try viewContext.setQueryGenerationFrom(.current)
  }
}
