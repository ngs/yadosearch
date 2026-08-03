import Foundation

/// A read-only XML element tree.
///
/// The Jalan Web Service answers in XML. Its documents are small, shallow and
/// made entirely of text elements and attributes, so building the whole tree
/// costs nothing and reads far better at the call site than threading a
/// streaming parser through every model.
public struct XMLTreeNode: Sendable, Equatable {
    public let name: String
    public let attributes: [String: String]
    /// The element's own character data, with surrounding whitespace removed.
    public let text: String
    public let children: [XMLTreeNode]

    public init(
        name: String,
        attributes: [String: String] = [:],
        text: String = "",
        children: [XMLTreeNode] = []
    ) {
        self.name = name
        self.attributes = attributes
        self.text = text
        self.children = children
    }
}

public extension XMLTreeNode {
    func children(named name: String) -> [XMLTreeNode] {
        children.filter { $0.name == name }
    }

    func child(named name: String) -> XMLTreeNode? {
        children.first { $0.name == name }
    }

    /// The text of the first child element with this name — `nil` when the
    /// element is absent, and also when it is present but empty, which the API
    /// uses interchangeably (`<WifiHikariStation></WifiHikariStation>`).
    func string(_ name: String) -> String? {
        child(named: name)?.text.nonEmpty
    }

    func int(_ name: String) -> Int? {
        string(name).flatMap(Int.init)
    }

    func double(_ name: String) -> Double? {
        string(name).flatMap(Double.init)
    }

    func url(_ name: String) -> URL? {
        string(name).flatMap { URL(string: $0) }
    }

    /// An attribute of this element, empty values treated as absent.
    func attribute(_ name: String) -> String? {
        attributes[name]?.nonEmpty
    }
}

extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
