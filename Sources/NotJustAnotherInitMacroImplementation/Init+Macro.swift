import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Generates a  initialiser for a `class` or `struct`.
///
/// This macro will extract all mutable properties (constants with no default values and variables) and add them to the signature of the initialiser.
/// The order of the signature entries is defined by the order they appear inside of the hosting object.
///
/// SwiftSyntax does not provide the inferred type of the variable
/// as discussed [here](https://forums.swift.org/t/extracting-the-inferred-type-with-swiftsyntax/66886).
/// A manual analysis is done on the most common types (Bool, String, Int, Arrays and Dictionaries).
/// Other types however, especially custom ones will have to have an explicit type other than the default value.
///
/// The macro will make validate the access levels.
/// The macro will throw errors whenever something is wrong with the syntax.
public struct InitMacro: MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // Make sure the declaration is either a `struct` or `class`.
    guard declaration.is(StructDeclSyntax.self) || declaration.is(ClassDeclSyntax.self) else {
      throw Error.invalidType
    }

    // Make sure it is not private or fileprivate.
    if declaration.modifiers.contains(where: { ($0.name.tokenKind == .keyword(.private) || $0.name.tokenKind == .keyword(.fileprivate)) }) {
      throw Error.invalidAccessLevel
    }

    let requestedAccessLevel = getAccessLevel(of: node)

    // An internal object cannot have a public initialiser. It does not make sense.
    guard getAccessLevel(of: declaration) >= requestedAccessLevel else {
      throw Error.invalidAccessLevelHierarchy
    }

    let content = try getParametersAndStatements(
      of: declaration,
      keysToExclude: getKeysToExclude(from: node),
      defaultValues: getDefaultValues(from: node)
    )

    let header: SyntaxNodeString = if content.count <= 2 {
      "\(raw: requestedAccessLevel.rawValue) init(\(raw: content.map(\.0).joined(separator: ", ")))"
    } else {
      "\(raw: requestedAccessLevel.rawValue) init(\n\(raw: content.map(\.0).joined(separator: ",\n"))\n)"
    }

    let body = content
      .map(\.1)
      .map {
        var output = ExprSyntax("\(raw: $0)")
        output.trailingTrivia = .newlines(1)
        return output
      }

    let initializerSyntax = try InitializerDeclSyntax(header) {
      for expression in body {
        expression
      }
    }

    return ["\(raw: initializerSyntax)"]
  }
}

extension InitMacro {
  private static func getParametersAndStatements(
    of declaration: some DeclGroupSyntax,
    keysToExclude: [String],
    defaultValues: [String: String]
  ) throws -> [(String, String)] {
    var allKeys: [String] = []
    
    let parametersAndStatements = try declaration.memberBlock.members
      .reduce(into: [(String, String)]()) { partialResult, member in
        guard
          let syntax = member.decl.as(VariableDeclSyntax.self),
          let bindings = syntax.bindings.as(PatternBindingListSyntax.self),
          let pattern = bindings.first?.as(PatternBindingSyntax.self),
          let identifier = (pattern.pattern.as(IdentifierPatternSyntax.self))?.identifier.trimmed.text
        else {
          return
        }

        // Track the keys in the object to make sure the requested keys to filter are properly spelled..
        allKeys.append(identifier)
        
        // Make sure excluded key is initialised.
        if keysToExclude.contains(identifier) {
          guard pattern.initializer != nil else {
            throw Error.excludingNonInitialisedProperty(named: identifier)
          }

          return
        }
        
        // Do not include static properties
        if syntax.modifiers.as(DeclModifierListSyntax.self)?.contains(where: {$0.as(DeclModifierSyntax.self)?.name.text == "static"}) == true {
          return
        }

        if
          // Initialised constants should not be included.
          syntax.bindingSpecifier.tokenKind == .keyword(.let) && pattern.initializer != nil ||
            // Computed property
            pattern.accessorBlock != nil
        {
          return
        }

        let type = (pattern.typeAnnotation?.as(TypeAnnotationSyntax.self))?.type
        if var typeValue = type?.description.trimmingCharacters(in: .whitespacesAndNewlines) ?? extractType(from: pattern) {
          typeValue = type?.is(FunctionTypeSyntax.self) == true ? "@escaping " + typeValue : typeValue

          let assignment = "self.\(identifier) = \(identifier)"
          let parameter = if let defaultValue = defaultValues[identifier] {
            "\(identifier): \(typeValue) = \(defaultValue)"
          } else {
            "\(identifier): \(typeValue)"
          }

          partialResult.append((parameter, assignment))
        } else {
          throw Error.cannotInferType(variable: "\(identifier)")
        }
      }
    
    try keysToExclude.forEach {
      guard allKeys.contains($0) else {
        throw Error.inexistentKey(named: $0)
      }
    }
    
    try defaultValues.keys.forEach {
      guard allKeys.contains($0) else {
        throw Error.inexistentKey(named: $0)
      }
    }
    
    return parametersAndStatements
  }

  /// Extract and transforms an `ExprSyntax` into an equivalent `String` representation.
  ///
  /// - Parameter binding: A `PatternBindingSyntax` to decompose.
  /// - Returns: A `String` representation of the embedded `ExprSyntax`.
  private static func extractType(from binding: PatternBindingSyntax) -> String? {
    guard let initializer = binding.initializer else {
      return nil
    }

    // 3.9 as Float || [3, "Hi"] as [Any] || ["key": "value", "anotherKey": 1] as [String: Any]
    if
      let sequenceSyntax = binding.initializer?.value.as(SequenceExprSyntax.self),
      let castedType = sequenceSyntax.elements.first(where: { $0.kind == .typeExpr })?.description {
      let isOptional = sequenceSyntax.elements
        .first(where: { $0.kind == .unresolvedAsExpr })?
        .as(UnresolvedAsExprSyntax.self)?
        .questionOrExclamationMark != nil

      return isOptional ? "\(castedType)?" : castedType
    }

    if let arraySyntax = initializer.value.as(ArrayExprSyntax.self) {
      // A non homogenous array has to be either explicitly declared or casted.
      // Getting to this point we can assume it's something like `let array = [1, 3, 8]`.
      guard
        let firstElement = arraySyntax.elements.first,
        var type = extractType(from: firstElement.expression)
      else {
        return nil
      }

      type = arraySyntax.elements.contains(where: { $0.expression.is(NilLiteralExprSyntax.self) }) ? "\(type)?" : type
      return "[\(type)]"
    }

    if let dictionarySyntax = initializer.value.as(DictionaryExprSyntax.self) {
      // A non homogenous dictionary has to be either explicitly declared or casted.
      // Getting to this point we can assume it's an array with  homogeneous key, and type.
      guard
        let dictionaryListSyntax = dictionarySyntax.content.as(DictionaryElementListSyntax.self),
        let anyElement = dictionaryListSyntax.first(where: { !$0.value.is(NilLiteralExprSyntax.self) }),
        let keyType = extractType(from: anyElement.key),
        var valueType = extractType(from: anyElement.value)
      else {
        return nil
      }

      valueType = dictionaryListSyntax.contains(where: { $0.value.is(NilLiteralExprSyntax.self) }) ? "\(valueType)?" : valueType
      return "[\(keyType): \(valueType)]"
    }

    return extractType(from: initializer.value)
  }

  /// Transforms an `ExprSyntax` into an equivalent `String` representation.
  ///
  /// Example: BooleanLiteralExprSyntax => Bool
  /// - Parameter expression: An `ExprSyntax` value.
  /// - Returns: A `String` representation. `nil` if not applicable.
  private static func extractType(from expression: ExprSyntax) -> String? {
    if expression.is(BooleanLiteralExprSyntax.self) {
      return "Bool"
    }

    if expression.is(StringLiteralExprSyntax.self) {
      return "String"
    }

    if expression.is(IntegerLiteralExprSyntax.self) {
      return "Int"
    }

    // Non casted FloatLiteralExprSyntax are inferred as `Double` by the compiler.
    if expression.is(FloatLiteralExprSyntax.self) {
      return "Double"
    }

    if expression.is(NilLiteralExprSyntax.self) {
      return "nil"
    }

    return nil
  }

  private static func getAccessLevel(of node: AttributeSyntax) -> AccessLevel {
    let accessLevel: AccessLevel = switch node
      .arguments?.as(LabeledExprListSyntax.self)?
      .first(where: { $0.label?.tokenKind == .identifier("accessLevel") })?
      .expression.as(MemberAccessExprSyntax.self)?
      .declName.baseName {
      case let .some(token): token.text == "public" ? .public : .internal
      case .none: .public
    }

    return accessLevel
  }

  private static func getAccessLevel(of declaration: some DeclGroupSyntax) -> AccessLevel {
    return declaration.modifiers.contains(
      where: { ($0.name.tokenKind == .keyword(.public) || $0.name.tokenKind == .keyword(.open)) }
    ) ? .public : .internal
  }

  private static func getKeysToExclude(from node: AttributeSyntax) -> [String] {
    return node
      .arguments?.as(LabeledExprListSyntax.self)?
      .first(where: { $0.label?.tokenKind == .identifier("exclude") })?
      .expression.as(ArrayExprSyntax.self)?
      .elements
      .compactMap({
        $0.expression.as(StringLiteralExprSyntax.self)?
          .segments.as(StringLiteralSegmentListSyntax.self)?
          .first?.as(StringSegmentSyntax.self)?
          .content
          .text
      }) ?? []
  }

  private static func getDefaultValues(from node: AttributeSyntax) -> [String: String] {
    return node
      .arguments?.as(LabeledExprListSyntax.self)?
      .first(where: { $0.label?.tokenKind == .identifier("defaultValues") })?
      .expression.as(DictionaryExprSyntax.self)?
      .content.as(DictionaryElementListSyntax.self)?
      .reduce(into: [String: String](), { partialResult, element in
        guard let key = element.key.as(StringLiteralExprSyntax.self)?.segments.first?.as(StringSegmentSyntax.self)?.content.text else {
          return
        }

        partialResult[key] = "\(element.value)"
      }) ?? [:]
  }
}
