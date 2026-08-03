import Foundation

public enum XMLTreeError: Error, Sendable, Equatable {
    /// The document could not be parsed; the payload is `XMLParser`'s own
    /// description, kept as a string so the error stays `Sendable`.
    case malformed(String?)
    /// The document parsed but had no root element.
    case empty
}

public enum XMLTree {
    /// Parses a whole document into a tree.
    ///
    /// Namespace processing stays off deliberately: every Jalan response declares
    /// the default namespace `jws`, and with processing enabled the element names
    /// would arrive stripped of nothing but the parser would also start reporting
    /// namespace prefixes the documents never use.
    public static func parse(_ data: Data) throws -> XMLTreeNode {
        let builder = XMLTreeBuilder()
        let parser = XMLParser(data: data)
        parser.delegate = builder
        guard parser.parse() else {
            throw XMLTreeError.malformed(parser.parserError?.localizedDescription)
        }
        guard let root = builder.root else {
            throw XMLTreeError.empty
        }
        return root
    }
}

/// Builds the tree depth-first. Not `Sendable`, and never needs to be: it lives
/// and dies inside a single synchronous `parse` call.
private final class XMLTreeBuilder: NSObject, XMLParserDelegate {
    private struct Frame {
        let name: String
        let attributes: [String: String]
        var text: String
        var children: [XMLTreeNode]
    }

    private var stack: [Frame] = []
    private(set) var root: XMLTreeNode?

    func parser(
        _: XMLParser,
        didStartElement elementName: String,
        namespaceURI _: String?,
        qualifiedName _: String?,
        attributes attributeDict: [String: String]
    ) {
        stack.append(Frame(name: elementName, attributes: attributeDict, text: "", children: []))
    }

    func parser(_: XMLParser, foundCharacters string: String) {
        guard !stack.isEmpty else { return }
        stack[stack.count - 1].text += string
    }

    func parser(_: XMLParser, foundCDATA CDATABlock: Data) {
        guard !stack.isEmpty, let text = String(data: CDATABlock, encoding: .utf8) else { return }
        stack[stack.count - 1].text += text
    }

    func parser(
        _: XMLParser,
        didEndElement _: String,
        namespaceURI _: String?,
        qualifiedName _: String?
    ) {
        guard let frame = stack.popLast() else { return }
        let node = XMLTreeNode(
            name: frame.name,
            attributes: frame.attributes,
            text: frame.text.trimmingCharacters(in: .whitespacesAndNewlines),
            children: frame.children
        )
        if stack.isEmpty {
            root = node
        } else {
            stack[stack.count - 1].children.append(node)
        }
    }
}
