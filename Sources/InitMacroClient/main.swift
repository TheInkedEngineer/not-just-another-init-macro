import InitMacro

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
