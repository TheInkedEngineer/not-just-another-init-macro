extension InitMacro {
  public enum AccessLevel: String, Equatable, Comparable {
    /// Creates an internal initialiser.
    case `internal` = "internal"

    /// Creates an public initialiser.
    case `public` = "public"

    public static func < (lhs: InitMacro.AccessLevel, rhs: InitMacro.AccessLevel) -> Bool {
      lhs == .internal && rhs == .public
    }
  }
}
