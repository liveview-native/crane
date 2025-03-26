// import ArgumentParser
import Foundation

import GRPCCore
import GRPCNIOTransportHTTP2
import GRPCProtobuf

@preconcurrency import LiveViewNativeCore

@Observable
public final class Crane: @unchecked Sendable {
    let client: GRPCClient<HTTP2ClientTransport.Posix>
    let browserService: CraneBrowserService.Client<HTTP2ClientTransport.Posix>
    let windowService: CraneWindowService.Client<HTTP2ClientTransport.Posix>
    var runloop: Task<Void, any Error>?
    
    public var windows = [Window]()
    
    @Observable
    public final class Window: @unchecked Sendable {
        public let window: CraneWindow
        public var url: URL
        public var document: Document
        public var stylesheets: [String]
        public var history: CraneHistory
        
        public var canGoBack: Bool {
            history.index > history.stack.indices.lowerBound
        }
        
        public var canGoForward: Bool {
            history.index < history.stack.index(before: history.stack.endIndex)
        }
        
        init(
            window: CraneWindow,
            url: URL,
            document: Document,
            stylesheets: [String],
            history: CraneHistory
        ) {
            self.window = window
            self.url = url
            self.document = document
            self.stylesheets = stylesheets
            self.history = history
        }
    }

    public init() {
        self.client = try! GRPCClient(transport: .http2NIOPosix(
            target: .ipv4(host: "127.0.0.1", port: 50051),
            transportSecurity: .plaintext
        ))
        self.browserService = CraneBrowserService.Client(wrapping: self.client)
        self.windowService = CraneWindowService.Client(wrapping: client)
        self.runloop = Task { [weak client] in
            while true {
                do {
                    try await client?.runConnections()
                    return
                } catch {
                    print(error)
                    print("retrying")
                }
            }
        }
    }
    
    @discardableResult
    public func newWindow(url: URL) async throws -> Window {
        let craneWindow = try await windowService.new(CraneWindow())
        
        var request = CraneRequest()
        request.url = url.absoluteString
        request.windowName = craneWindow.name
        request.method = "GET"
        
        var header = CraneHeader()
        header.name = "Accept"
        header.value = "application/swiftui"
        request.headers = [
            header
        ]
        
        let response = try await windowService.visit(request)
        let document = response.viewTrees["main"]!
        let window = Window(
            window: craneWindow,
            url: url,
            document: GRPCDocument(
                document: document
            ),
            stylesheets: response.stylesheets,
            history: response.history
        )
        self.windows.append(window)
        return window
    }
    
    @discardableResult
    public func refresh(window: Window) async throws -> Window {
        let response = try await windowService.refresh(window.window)
        let document = response.viewTrees["main"]!
        window.document = GRPCDocument(
            document: document
        )
        window.stylesheets = response.stylesheets
        window.history = response.history
        print("reloaded")
        return window
    }
    
    @discardableResult
    public func navigate(window: Window, to url: URL) async throws -> Window {
        var request = CraneRequest()
        request.url = url.absoluteString
        request.windowName = window.window.name
        request.method = "GET"
        
        var header = CraneHeader()
        header.name = "Accept"
        header.value = "application/swiftui"
        request.headers = [
            header
        ]
        
        let response = try await windowService.visit(request)
        let document = response.viewTrees["main"]!
        window.url = url
        window.document = GRPCDocument(
            document: document
        )
        window.stylesheets = response.stylesheets
        window.history = response.history
        return window
    }
    
    @discardableResult
    public func back(window: Window) async throws -> Window {
        let response = try await windowService.back(window.window)
        let document = response.viewTrees["main"]!
        window.document = GRPCDocument(
            document: document
        )
        window.stylesheets = response.stylesheets
        window.history = response.history
        return window
    }
    
    @discardableResult
    public func forward(window: Window) async throws -> Window {
        let response = try await windowService.forward(window.window)
        let document = response.viewTrees["main"]!
        window.document = GRPCDocument(
            document: document
        )
        window.stylesheets = response.stylesheets
        window.history = response.history
        return window
    }
    
    public func close(window: Window) async throws {
        let response = try await windowService.close(window.window)
        self.windows.removeAll(where: { $0.window.name == window.window.name })
    }
    
    deinit {
        runloop?.cancel()
    }
}

final class CraneNodeRef: LiveViewNativeCore.NodeRef {
    let value: Int32

    required init(unsafeFromRawPointer pointer: UnsafeMutableRawPointer) {
        fatalError("cannot init from a pointer")
    }

    init(_ value: Int32) {
        self.value = value
        super.init(noPointer: .init())
    }

    override func ref() -> Int32 {
        value
    }
}

final class GRPCDocument: LiveViewNativeCore.Document {
    var rootNode: GRPCNode!
    var nodes = [Int32:GRPCNode]()

    required init(unsafeFromRawPointer pointer: UnsafeMutableRawPointer) {
        fatalError("cannot init from a pointer")
    }

    init(document: CraneDocument) {
        super.init(noPointer: .init())
        var rootNode = CraneNode()
        rootNode.type = "root"
        rootNode.id = -1
        rootNode.children = document.nodes
        self.rootNode = GRPCNode(rootNode, id: rootNode.id, parentID: nil, document: self)
        nodes[self.rootNode.grpcNode.id] = self.rootNode
        var unhandledNodes = [(rootNode, parent: Int32(-2))]
        while let (node, parent) = unhandledNodes.popLast() {
            let grpcNode = GRPCNode(node, id: node.id, parentID: parent, document: self)
            nodes[node.id] = grpcNode
            if parent >= -1 {
                self.nodes[parent]!.childrenIDs.append(grpcNode.nodeId())
            }
            unhandledNodes.insert(contentsOf: node.children.reversed().map { ($0, parent: node.id) }, at: 0)
        }
    }

    override func children(_ nodeRef: NodeRef) -> [NodeRef] {
        nodes[nodeRef.ref()]!.childrenIDs
    }

    override func get(_ nodeRef: NodeRef) -> NodeData {
        nodes[nodeRef.ref()]!.data()
    }

    override func getAttributes(_ nodeRef: NodeRef) -> [LiveViewNativeCore.Attribute] {
        self.getNode(nodeRef).attributes()
    }

    override func getNode(_ nodeRef: NodeRef) -> LiveViewNativeCore.Node {
        nodes[nodeRef.ref()]!
    }

    override func getParent(_ nodeRef: NodeRef) -> NodeRef? {
        nodes[nodeRef.ref()]?.parentID
    }

    override func mergeFragmentJson(_ json: String) throws {
        fatalError("diff merging is not supported")
    }

    override func nextUploadId() -> UInt64 {
        fatalError("Uploads are not supported")
    }

    override func render() -> String {
        """
        render document to string
        """
    }

    override func root() -> NodeRef {
        rootNode.nodeId()
    }

    override func setEventHandler(_ handler: DocumentChangeHandler) {
        fatalError("document change events are not supported")
    }
}

final class GRPCNode: LiveViewNativeCore.Node {
    let grpcNode: CraneNode
    let nodeRef: NodeRef
    let parentID: NodeRef?
    var childrenIDs: [NodeRef] = []
    unowned var grpcDocument: GRPCDocument

    required init(unsafeFromRawPointer pointer: UnsafeMutableRawPointer) {
        fatalError("cannot init from a pointer")
    }

    init(_ grpcNode: CraneNode, id: Int32, parentID: Int32?, document: GRPCDocument) {
        self.grpcNode = grpcNode
        self.nodeRef = CraneNodeRef(id)
        self.parentID = parentID.map { CraneNodeRef($0) }
        self.grpcDocument = document
        super.init(noPointer: .init())
    }

    override func attributes() -> [LiveViewNativeCore.Attribute] {
        grpcNode.attributes.map {
            LiveViewNativeCore.Attribute(name: AttributeName(rawValue: $0.name)!, value: $0.value)
        }
    }

    override func data() -> LiveViewNativeCore.NodeData {
        switch grpcNode.type {
        case "text":
            return .leaf(value: grpcNode.textContent.trimmingCharacters(in: .whitespacesAndNewlines))
        case "root":
            return .root
        default:
            return .nodeElement(element: LiveViewNativeCore.Element(name: ElementName(namespace: nil, name: grpcNode.tagName), attributes: attributes()))
        }
    }

    override func display() -> String {
        """
        <\(grpcNode.tagName) />
        """
    }

    override func document() -> LiveViewNativeCore.Document {
        self.grpcDocument
    }

    override func getAttribute(_ name: AttributeName) -> LiveViewNativeCore.Attribute? {
        attributes().first(where: { $0.name == name })
    }

    override func getChildren() -> [LiveViewNativeCore.Node] {
        self.childrenIDs.map {
            self.grpcDocument.getNode($0)
        }
    }

    override func getDepthFirstChildren() -> [LiveViewNativeCore.Node] {
        var out = [LiveViewNativeCore.Node]()
        
        for child in self.getChildren() {
            out.append(child)
            let depth = child.getDepthFirstChildren()
            out.append(contentsOf: depth)
        }
        return out
    }

    override func nodeId() -> NodeRef {
        nodeRef
    }
}
