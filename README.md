# Not just another Init macro`

`Not just another Init macro` is a Swift macro to automatically generate an initialiser for a `struct` or `class`.
It is supercharged with features to make it as flexible as possible.

## Features

- Retrieves inferred basic data types, arrays and dictionaries 
- Support for arrays and dictionaries containing nil values.
- Support for casting.
- Support for escaping closures.
- Ability to generate a public or private initiliaser.
- Ability to omit variables from the initialiser.
- Ability to provide default values for variables in the initialiser.
- Diagnostic messages to avoid typos, wrong access level, etc..

## Usage

```swift
@Init(accessLevel: .internal, defaultValues: ["key2": true], exclude: ["key4"])
public struct Test {
  let key: String
  let key2: Bool
  let key3: Int
  var key4 = ["HI", "Bye"]
  var key5 = [3, "Int"] as [Any]
  var key6 = ["key": "value"]
  var key7 = ["key": "value", "anotherKey": 1] as [String: Any]
  var key8 = ["key": "value", 1: false] as [AnyHashable: Any]
  var key9 = 3.0 as Float
  var key10 = 3.0
  let optionalKey: String?
  var optionalKey2 = [3, nil]
  var optionalKey3 = ["key": nil] as [String: Any?]
  var optionalKey4 = [1: nil, 2: "value"]
  var optionalKey5 = 3.0 as Float
  var closure: (Int) -> ()
}
```
will generate:

```swift
internal init(
    key: String,
    key2: Bool = true,
    key3: Int,
    key5: [Any],
    key6: [String: String],
    key7: [String: Any],
    key8: [AnyHashable: Any],
    key9: Float,
    key10: Double,
    optionalKey: String?,
    optionalKey2: [Int?],
    optionalKey3: [String: Any?],
    optionalKey4: [Int: String?],
    optionalKey5: Float,
    closure: @escaping (Int) -> ()
) {
    self.key = key
    self.key2 = key2
    self.key3 = key3
    self.key5 = key5
    self.key6 = key6
    self.key7 = key7
    self.key8 = key8
    self.key9 = key9
    self.key10 = key10
    self.optionalKey = optionalKey
    self.optionalKey2 = optionalKey2
    self.optionalKey3 = optionalKey3
    self.optionalKey4 = optionalKey4
    self.optionalKey5 = optionalKey5
    self.closure = closure
}
``` 
