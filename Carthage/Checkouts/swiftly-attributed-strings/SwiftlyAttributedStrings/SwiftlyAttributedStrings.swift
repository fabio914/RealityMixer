import UIKit

public protocol StringNode {
}

extension String: StringNode {
}

open class Node: StringNode {
    
    public var params: [NSAttributedString.Key: Any]
    public var nodes: [StringNode]
    
    public init(params: [NSAttributedString.Key: Any], nodes: [StringNode]) {
        self.nodes = nodes
        self.params = params
    }
    
    public convenience init(params: [NSAttributedString.Key: Any], closure: () -> StringNode) {
        self.init(params: params, nodes: [closure()])
    }
}

public func +(lhs: StringNode, rhs: StringNode) -> Node {
    return Node(params: [:], nodes: [lhs, rhs])
}

public enum StringNodeError: Error {
    case invalidNodeInstance
}

public extension StringNode {
    
    func attributedString(context: [NSAttributedString.Key: Any] = [:]) throws -> NSAttributedString {
        
        if let string = self as? String {
            
            return NSAttributedString(string: string, attributes: context)
        }
            
        else if let node = self as? Node {
            
            let localAttributed = NSMutableAttributedString()
            let currentContext = context.merging(node.params, uniquingKeysWith: { $1 })
            try node.nodes.map({ try $0.attributedString(context: currentContext) }).forEach(localAttributed.append)
            return NSAttributedString(attributedString: localAttributed)
        }
            
        else {
            
            throw StringNodeError.invalidNodeInstance
        }
    }
    
    var attributedString: NSAttributedString? {
        return try? attributedString()
    }
}

//
// String Attribute Classes
//

public class Font: Node {
    
    public init(_ font: UIFont?, nodes: [StringNode]) {
        var params: [NSAttributedString.Key: Any] = [:]
        if let font = font { params[.font] = font }
        super.init(params: params, nodes: nodes)
    }
    
    public convenience init(_ font: UIFont?, closure: () -> StringNode) {
        self.init(font, nodes: [closure()])
    }
}

public class Color: Node {
    
    public init(_ color: UIColor, nodes: [StringNode]) {
        super.init(params: [.foregroundColor: color], nodes: nodes)
    }
    
    public convenience init(_ color: UIColor, closure: () -> StringNode) {
        self.init(color, nodes: [closure()])
    }
}

public class Underline: Node {
    
    public init(_ style: NSUnderlineStyle = NSUnderlineStyle.single, nodes: [StringNode]) {
        super.init(params: [.underlineStyle: style.rawValue], nodes: nodes)
    }
    
    public convenience init(_ style: NSUnderlineStyle = NSUnderlineStyle.single, closure: () -> StringNode) {
        self.init(style, nodes: [closure()])
    }
}
