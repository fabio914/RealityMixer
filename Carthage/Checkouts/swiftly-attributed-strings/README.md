# Swiftly Attributed Strings
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage) 

"Swiftly Attributed Strings" uses most of the Swift syntactic sugar to provide an easier way to instantiate NSAttributedStrings.

## Example

```swift
import SwiftlyAttributedStrings
// ...
@IBOutlet weak var label: UILabel!
// ...
label.attributedText = Underline() { Color(.blue) { "Hello, " + Font(.boldSystemFont(ofSize: 18)) { "World" } + "!" } }.attributedString
```

<img src="/1.jpg?raw=true" width="132">

## How to create your own string attributes
All you need to do is subclass ```Node``` and create one ```init()``` that takes an array of  ```StringNode``` and another one that takes a closure ```() -> StringNode```. These initializers will have to set the ```params``` dictionary accordingly (access [Character Attributes](https://developer.apple.com/reference/foundation/nsattributedstring/character_attributes) for more information).

### Example

```swift
import UIKit
import SwiftlyAttributedStrings

class Kern: Node {
    
    init(_ kern: Float = 0, nodes: [StringNode]) {
        var params: [NSAttributedString.Key: Any] = [:]
        if kern >= 0 { params[.kern] = kern }
        super.init(params: params, nodes: nodes)
    }
    
    convenience init(_ kern: Float = 0, closure: () -> StringNode) {
        self.init(kern, nodes: [closure()])
    }
}
```

```swift
label.attributedText = Kern(5) { Color(.green) { "Hello, " } + Color(.blue) { "World!" } }.attributedString
```

<img src="/2.jpg?raw=true" width="182">

## How to install

### CocoaPods

Add this line to your `Podfile`:

```
pod 'SwiftlyAttributedStrings', :git => 'https://github.com/fabio914/swiftly-attributed-strings.git', :tag => '2.0.0'
``` 

### Carthage

Add this line to your `Cartfile`:

```
github "fabio914/swiftly-attributed-strings" ~> 2.0
```

## Requirements
Swift 5, iOS 10.3+

## License
```Swiftly Attributed Strings``` is released under the ```MIT``` license.


