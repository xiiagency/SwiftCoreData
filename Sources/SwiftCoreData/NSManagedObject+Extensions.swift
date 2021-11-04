import CoreData

/**
 Provides data transformation short-hand for models that want to expose a type for their attributes that is different than th
 stored type attribute type (e.g. enum value vs stored `String`).
 
 Example:
   ```
   extension SomeNSManagedObjectType {
     var aliasedAttribute: String {
       get { get(storedAttribute) }
       set { storedAttribute = set(newValue) }
     }
   }
   ```
 */
extension NSManagedObject {
  /**
   Converts a stored  attribute of a given type from its optional form into a required one.
   
   NOTE: Will fatal error if the given value is nil.
   */
  public func get<Target>(_ value: Optional<Target>) -> Target {
    value!
  }
  
  /**
   Converts a stored `NSNumber` into an optional `Int`.
   */
  public func get(_ value: NSNumber?) -> Int? {
    value?.intValue
  }
  
  /**
   Converts an optional `Int` to a stored attribute value.
   */
  public func set(_ value: Int?) -> NSNumber? {
    if let value = value {
      return NSNumber(integerLiteral: value)
    }
    
    return nil
  }
  
  /**
   Converts a stored `NSNumber` into a required `Int`.
   
   NOTE: Will fatal error if the given value is nil.
   */
  public func get(_ value: NSNumber?) -> Int {
    get(value)!
  }
  
  /**
   Converts an `Int` to a stored attribute value.
   */
  public func set(_ value: Int) -> NSNumber? {
    NSNumber(integerLiteral: value)
  }
  
  /**
   Converts a stored `NSNumber` into a required `Double`.
   
   NOTE: Will fatal error if the given value is nil.
   */
  public func get(_ value: NSNumber?) -> Double {
    value!.doubleValue
  }
  
  /**
   Converts an `Double` to a stored attribute value.
   */
  public func set(_ value: Double) -> NSNumber? {
    NSNumber(floatLiteral: value)
  }
  
  /**
   Converts a stored `String` into an enum value.
   */
  public func get<Target : RawRepresentable>(
    _ value: String?
  ) -> Target where Target.RawValue == String {
    get(value)!
  }
  
  /**
   Converts an enum value to a stored attribute value.
   */
  public func set<Source : RawRepresentable>(
    _ value: Source
  ) -> String? where Source.RawValue == String {
    set(value as Source?)
  }
  
  /**
   Converts a stored `String` into an optional enum value.
   */
  public func get<Target : RawRepresentable>(
    _ value: String?
  ) -> Target? where Target.RawValue == String {
    guard let value = value else {
      return nil
    }
    
    return Target.init(rawValue: value)
  }
  
  /**
   Converts an enum value to a stored attribute value.
   */
  public func set<Source : RawRepresentable>(
    _ value: Source?
  ) -> String? where Source.RawValue == String {
    value?.rawValue
  }
  
  /**
   Converts a stored `String` to a `TimeZone`, where the stored value represents the time zone identifier.
   
   NOTE: Will fatal error if the given value is nil.
   */
  public func get(_ value: String?) -> TimeZone {
    TimeZone(identifier: value!)!
  }
  
  /**
   Converts a `TimeZone` to a stored attribute value (its identifier `String`).
   */
  public func set(_ value: TimeZone) -> String {
    value.identifier
  }
  
  /**
   Converts a stored relationship array to a required one.
   
   NOTE: Will fatal error if the given value is nil.
   */
  public func get<Target : NSManagedObject>(_ value: NSSet?) -> [Target] {
    (value?.allObjects as? [Target])!
  }
  
  /**
   Converts a relationship array to a stored attribute value.
   */
  public func set<Source : NSManagedObject>(_ value: [Source]) -> NSSet? {
    NSSet(array: value)
  }
  
  /**
   Converts a stored `String` into a `URL` value.
   
   NOTE: Will fatal error if the given value is nil.
   */
  public func get(_ value: String?) -> URL {
    URL(string: get(value))!
  }
  
  /**
   Converts a `URL` value to a stored attribute `String` value.
   */
  public func set(_ value: URL) -> String {
    value.absoluteString
  }
}
