import erlang

extension ErlangNode.Connection {
    private func sendRPC(
        _ module: String,
        _ function: String,
        _ arguments: [Term]
    ) throws {
        var args = ErlangTermBuffer()
        args.new()
        
        try Term.list(arguments).encode(to: &args, initializeBuffer: false)
        
        var result = ErlangTermBuffer()
        result.new()
        
        guard ei_rpc_to(
            &node.node,
            fileDescriptor,
            strdup(module),
            strdup(function),
            args.buff,
            args.index
        ) == 0
        else { throw ErlangNodeError.rpcFailed }
    }
    
    private func sendRPC(
        _ module: String,
        _ function: String,
        _ arguments: [any (Encodable & Sendable)]
    ) throws {
        let encoder = TermEncoder()
        encoder.options.includeVersion = false
        let args = try encoder.encode(
            arguments.map(RPCArgument.init(item:))
        )
        
        var result = ErlangTermBuffer()
        result.new()
        
        guard ei_rpc_to(
            &node.node,
            fileDescriptor,
            strdup(module),
            strdup(function),
            args.buff,
            args.index
        ) == 0
        else { throw ErlangNodeError.rpcFailed }
    }
    
    /// Makes an RPC call with a ``Term`` result type and ``Term``
    /// arguments.
    ///
    /// > Elixir modules must be prefixed with `Elixir.`
    /// >
    /// > By default, the ``module`` argument will refer to an Erlang module.
    public func rpc(
        _ module: String,
        _ function: String,
        _ arguments: [Term]
    ) async throws -> Term {
        let stream = self.messageBuffers()
        
        try await self.sendRPC(module, function, arguments)
        
        for try await message in stream { // find the :rex message
            let message = try message.get()
            
            var index: Int32 = 0
            var arity: Int32 = 0
            var atom: [CChar] = [CChar](repeating: 0, count: Int(MAXATOMLEN))
            
            var version: Int32 = 0
            message.decode(version: &version, index: &index)
            
            message.decode(tupleHeader: &arity, index: &index)
            
            guard arity > 0,
                  message.decode(atom: &atom, index: &index),
                  String(cString: atom, encoding: .utf8) == "rex"
            else { continue }
            
            return try Term(from: message)
        }
        
        throw ErlangNodeError.rpcFailed
    }
    
    public func rpc<each Result: Decodable & Sendable>(
        _ module: String,
        _ function: String,
        _ arguments: [Term]
    ) async throws -> (repeat each Result) {
        let stream = self.messageBuffers()
        
        try await self.sendRPC(module, function, arguments)
        
        for try await message in stream { // find the :rex message
            let message = try message.get()
            
            var index: Int32 = 0
            var arity: Int32 = 0
            var atom: [CChar] = [CChar](repeating: 0, count: Int(MAXATOMLEN))
            
            var version: Int32 = 0
            message.decode(version: &version, index: &index)
            
            message.decode(tupleHeader: &arity, index: &index)
            
            guard arity > 0,
                  message.decode(atom: &atom, index: &index),
                  String(cString: atom, encoding: .utf8) == "rex"
            else { continue }
            
            return try TermDecoder().decode(
                RPCResult<repeat each Result>.self,
                from: message,
                startIndex: index
            ).value
        }
        
        throw ErlangNodeError.rpcFailed
    }
    
    /// Makes an RPC call with a ``Swift/Decodable`` result type and
    /// ``Swift/Encodable`` arguments.
    ///
    /// You can pass any `Encodable` type as an argument, and receive any number of
    /// ``Decodable`` types as a response.
    ///
    /// ```swift
    /// struct Version: Decodable {
    ///     let major: Int
    ///     let minor: Int
    ///     let patch: Int
    ///     let pre: [String]
    /// }
    ///
    /// let version: Version = connection.rpc("Elixir.Version", "parse", ["2.0.1-alpha1"])
    /// ```
    ///
    /// Assign the result to a tuple to decode multiple values.
    ///
    /// ```swift
    /// // from Elixir: {:ok, "John Doe", 36}
    /// let name: String, age: Int
    /// (name, age) = try await connection.rpc("Elixir.User", "get", [0])
    /// ```
    ///
    /// > Elixir modules must be prefixed with `Elixir.`
    /// >
    /// > By default, the ``module`` argument will refer to an Erlang module.
    public func rpc<each Result: Decodable & Sendable>(
        _ module: String,
        _ function: String,
        _ arguments: [any (Encodable & Sendable)]
    ) async throws -> (repeat each Result) {
        let stream = self.messageBuffers()
        
        try await self.sendRPC(module, function, arguments)
        
        for try await message in stream { // find the :rex message
            let message = try message.get()
            
            var index: Int32 = 0
            var arity: Int32 = 0
            var atom: [CChar] = [CChar](repeating: 0, count: Int(MAXATOMLEN))
            
            var version: Int32 = 0
            message.decode(version: &version, index: &index)
            
            message.decode(tupleHeader: &arity, index: &index)
            
            guard arity > 0,
                  message.decode(atom: &atom, index: &index),
                  String(cString: atom, encoding: .utf8) == "rex"
            else { continue }
            
            return try TermDecoder().decode(
                RPCResult<repeat each Result>.self,
                from: message,
                startIndex: index
            ).value
        }
        
        throw ErlangNodeError.rpcFailed
    }
    
    private func receive() throws -> ErlangTermBuffer? {
        var message = erlang_msg()
        var buffer = ErlangTermBuffer()
        buffer.new()
        
        switch ei_xreceive_msg_tmo(self.fileDescriptor, &message, &buffer.buffer, 1) {
        case ERL_TICK:
            return nil
        case ERL_ERROR:
            return nil
        default:
            return buffer
        }
    }
    
    /// Receives one message from a remote node, or `nil` if there are no
    /// messages to receive.
    public func receive() throws -> Term? {
        return try receive().flatMap({
            var buffer = $0
            return try Term(from: buffer)
        })
    }
    
    /// Receives one ``Swift/Decodable`` message from a remote node, or
    /// `nil` if there are no messages to receive.
    public func receive<Result: Decodable>() throws -> Result? {
        return try receive().flatMap({ try termDecoder.decode(Result.self, from: $0) })
    }
    
    private enum RPCStatus: String, Decodable {
        case ok
        case badrpc
    }
    
    private struct RPCArgument: Encodable {
        let item: any Encodable
        
        func encode(to encoder: any Encoder) throws {
            var container = try encoder.singleValueContainer()
            try container.encode(item)
        }
    }
    
    private struct RPCResult<each Value: Decodable>: Decodable {
        let status: RPCStatus
        let value: (repeat each Value)
        
        init(from decoder: any Decoder) throws {
            var container = try decoder.unkeyedContainer()
            self.status = try container.decode(RPCStatus.self)
            switch self.status {
            case .ok:
                self.value = (
                    repeat try container.decode((each Value).self)
                )
            case .badrpc:
                throw ErlangNodeError.rpcFailed
            }
        }
    }
}
