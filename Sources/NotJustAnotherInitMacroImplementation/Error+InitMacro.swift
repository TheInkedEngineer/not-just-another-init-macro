extension InitMacro {
  enum Error: Swift.Error, CustomStringConvertible {
    case invalidAccessLevel
    case invalidAccessLevelHierarchy
    case invalidType
    case cannotInferType(variable: String)
    case excludingNonInitialisedProperty(named: String)
    case inexistentKey(named: String)

    var description: String {
      switch self {
        case .invalidAccessLevel:
          return "Invalid access level. Macro only works with open, public or internal."

        case .invalidAccessLevelHierarchy:
          return "The requested access level is higher than the object's access level."

        case .invalidType:
          return "This macro only works with `struct` and `class`."

        case let .cannotInferType(variable):
          return "Could not infer the type for \(variable). Please specify it explicitly."

        case let .excludingNonInitialisedProperty(name):
          return "Property \(name) was excluded without being initialised."
          
        case let .inexistentKey(name):
          return "\(name) is not a property."
      }
    }
  }
}
