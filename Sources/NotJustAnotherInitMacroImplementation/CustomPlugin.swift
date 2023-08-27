import Foundation
import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct CustomPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    InitMacro.self
  ]
}
