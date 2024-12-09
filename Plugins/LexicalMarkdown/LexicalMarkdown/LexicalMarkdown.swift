/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation
import Lexical
import LexicalLinkPlugin
import Markdown

open class LexicalMarkdown: Plugin {
  public init() {}

  weak var editor: Editor?

  public func setUp(editor: Editor) {
    self.editor = editor
  }

  public func tearDown() {
  }

  public class func generateMarkdown(from editor: Editor,
                                     selection: BaseSelection?) throws -> String {
    var markdownString = ""
    try editor.read {
      guard let root = getRoot() else {
        throw LexicalError.invariantViolation("Expected root node")
      }
      markdownString = Markdown.Document(root.getChildren().exportAsBlockMarkdown()).format()
    }
    return markdownString
  }
    
    public class func insertFromMarkdown(with editor: Editor, markdown: Document) throws {
        try editor.update {
            guard let root = getRoot() else {
              throw LexicalError.invariantViolation("Expected root node")
            }
            
            try root.append(
                markdown.root.children.compactMap { child in
                    try? (child as? MarkdownNodeSupport)?.getNode()
                }
            )
        }
    }
}

class LexicalMarkdownImporter {
    
    static let shared: LexicalMarkdownImporter = .init()
    
    private init() { }
    
    var isUnderlined: Bool = false
}

protocol MarkdownNodeSupport: Markup {
    func getNode() throws -> Node
}

extension Paragraph: MarkdownNodeSupport {
    func getNode() throws -> Node {
        let node = ParagraphNode()
        try node.append(
            children.compactMap { child in
                try? (child as? MarkdownNodeSupport)?.getNode()
            }
        )
        return node
    }
}

extension Heading: MarkdownNodeSupport {
    func getNode() throws -> Node {
        let node = HeadingNode(tag: levelTagType)
        try node.append(
            children.compactMap { child in
                try? (child as? MarkdownNodeSupport)?.getNode()
            }
        )
        return node
    }
}

extension Heading {
    var levelTagType: HeadingTagType {
        switch level {
        case 1: .h1
        case 2: .h2
        case 3: .h3
        case 4: .h4
        case 5: .h5
        default: .h1
        }
    }
}

extension Text: MarkdownNodeSupport {
    func getNode() throws -> Node {
        var format: TextFormat = .init()
        format.underline = LexicalMarkdownImporter.shared.isUnderlined
        return try TextNode(text: plainText).setFormat(format: format)
    }
}

extension Strong: MarkdownNodeSupport {
    func getNode() throws -> Node {
        var format: TextFormat = .init()
        format.bold = true
        format.italic = children.contains(where: { $0 is Emphasis })
        format.underline = children.contains(where: { $0 is Underline }) || LexicalMarkdownImporter.shared.isUnderlined
        return try TextNode(text: plainText).setFormat(format: format)
    }
}

extension Emphasis: MarkdownNodeSupport {
    func getNode() throws -> Node {
        var format: TextFormat = .init()
        format.italic = true
        format.bold = children.contains(where: { $0 is Strong })
        format.underline = children.contains(where: { $0 is Underline }) || LexicalMarkdownImporter.shared.isUnderlined
        return try TextNode(text: plainText).setFormat(format: format)
    }
}

extension Underline: MarkdownNodeSupport {
    func getNode() throws -> Node {
        var format: TextFormat = .init()
        format.underline = true
        format.bold = children.contains(where: { $0 is Strong })
        format.italic = children.contains(where: { $0 is Emphasis })
        return try TextNode(text: plainText).setFormat(format: format)
    }
}

extension InlineHTML: MarkdownNodeSupport {
    func getNode() throws -> Node {
        if rawHTML == "<u>" {
            LexicalMarkdownImporter.shared.isUnderlined = true
        } else if rawHTML == "</u>" {
            LexicalMarkdownImporter.shared.isUnderlined = false
        }
        return TextNode()
    }
}

extension Link: MarkdownNodeSupport {
    func getNode() throws -> Node {
        let node = LinkNode()
        try node.setURL(destination ?? "")
        try node.append(
            children.compactMap { child in
                try? (child as? MarkdownNodeSupport)?.getNode()
            }
        )
        return node
    }
}
