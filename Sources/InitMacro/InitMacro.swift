import InitMacroImplementation

/// Generates an initialiser.
///
/// Example:
///
/// ```swift
///  @Init
///  public struct Test {
///    let key: String
///  }
///  ```
/// generates the following output:
///
/// ```swift
///   public struct Test {
///     let key: String
///
///     public init(key: String) {
///       self.key = key
///     }
///  }
/// ```
///
/// - Parameters:
///   - defaultValues: A key-value object where the key represents the name of the property with which to assign a default value in the initialiser.
///   - exclude: An array of property names to exclude from the initialiser.
///              These values should be spelled correctly as those properties, and can be excluded when applicable.
///              You cannot exclude a non initialised property. Initialised constants will be excluded automatically.
///   - accessLevel: The access level associated with the initialiser. A value of `InitMacro.AccessLevel`. The access level
///                  cannot be higher than that of the enclosing object. Defaults to `.public`.
@attached(member, names: named(init))
public macro Init(
  accessLevel: InitMacro.AccessLevel = .public,
  defaultValues: [String: Any] = [:],
  exclude: [String] = []
) = #externalMacro(module: "InitMacroImplementation", type: "InitMacro")
