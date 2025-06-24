import Observation
import Foundation
import Combine
import erlang

extension Array {
    init<Tuple>(tuple: Tuple, start: KeyPath<Tuple, Element>) {
        self = withUnsafePointer(to: tuple) { pointer in
            return [Element](UnsafeBufferPointer(
                start: pointer.pointer(to: start)!,
                count: MemoryLayout.size(ofValue: pointer.pointee) / MemoryLayout.size(ofValue: pointer.pointee[keyPath: start])
            ))
        }
    }
}

extension String {
    func tuple<each T: FixedWidthInteger>() -> (repeat each T) {
        var result: (repeat each T) = (repeat (each T).zero)
        withUnsafeMutableBytes(of: &result) { pointer in
            pointer.copyBytes(from: utf8.prefix(pointer.count))
        }
        return result
    }
}

/// A generic type that can be returned by an ``ErlangNode`` representing any
/// term.
public enum Term: Sendable, Hashable {
    case int(Int)
    case double(Double)
    
    case atom(String)
    
    case string(String)
    
    case ref(Reference)
    
    case port(Port)
    
    case pid(PID)
    
    case tuple([Term])
    
    case list([Term])
    
    case binary(Data)
    
    case bitstring(Data)
    
    case function(Function)
    
    case map([Term:Term])
    
    public struct Reference: Sendable, Hashable {
        var ref: erlang_ref
        
        public static func == (lhs: Self, rhs: Self) -> Bool {
            var lhs = lhs
            var rhs = rhs
            return ei_cmp_refs(&lhs.ref, &rhs.ref) == 0
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(ref.creation)
            hasher.combine(ref.len)
            hasher.combine(Array(tuple: ref.n, start: \.0))
            hasher.combine(Array(tuple: ref.node, start: \.0))
        }
    }
    
    public struct Port: Sendable, Hashable {
        var port: erlang_port
    
        public static func == (lhs: Self, rhs: Self) -> Bool {
            var lhs = lhs
            var rhs = rhs
            return ei_cmp_ports(&lhs.port, &rhs.port) == 0
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(port.creation)
            hasher.combine(port.id)
            hasher.combine(Array(tuple: port.node, start: \.0))
        }
    }
    
    public struct PID: Sendable, Hashable, Decodable {
        var pid: erlang_pid
        
        init(pid: erlang_pid) {
            self.pid = pid
        }
        
        public static func == (lhs: Self, rhs: Self) -> Bool {
            var lhs = lhs
            var rhs = rhs
            return ei_cmp_pids(&lhs.pid, &rhs.pid) == 0
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(pid.creation)
            hasher.combine(pid.num)
            hasher.combine(pid.serial)
            hasher.combine(Array(tuple: pid.node, start: \.0))
        }
        
        public init(from decoder: any Decoder) throws {
            guard let decoder = decoder as? __TermDecoder
            else { fatalError("PID cannot be decoded outside of TermDecoder") }
            
            var pid = erlang_pid()
            ei_decode_pid(decoder.buffer.buff, &decoder.index, &pid)
            self.pid = pid
        }
    }
    
    public final class Function: @unchecked Sendable, Hashable {
        var fun: erlang_fun
        
        @MainActor private static var closures = [Term.PID: [(ErlangTermBuffer, Int32) throws -> ErlangTermBuffer]]()
        @MainActor static func call(
            callee: Term.PID,
            id: Int,
            arguments: sending ErlangTermBuffer,
            argumentsStartIndex: Int32
        ) async throws -> sending ErlangTermBuffer {
            try closures[callee]![id](arguments, argumentsStartIndex)
        }
        
        init(fun: erlang_fun) {
            self.fun = fun
        }
        
        private struct ArgumentList<
            each Argument: Decodable & Sendable
        >: Decodable, Sendable {
            let arguments: (repeat each Argument)
            
            init(from decoder: any Decoder) throws {
                var container = try decoder.unkeyedContainer()
                self.arguments = (
                    repeat try container.decode((each Argument).self)
                )
            }
        }
        
        /// Creates a closure that can be called from Elixir.
        ///
        /// Any closure you send to Elixir can be called an arbitrary number of
        /// times.
        ///
        /// - Warning: Closures do *not* support reentrancy. The remote node
        /// that calls the function will block until the closure returns.
        @MainActor public init<
            each Argument: Decodable & Sendable,
            each Result: Encodable & Sendable
        >(
            callee: Term.PID,
            _ action: sending @escaping (repeat each Argument) throws -> (repeat each Result)
        ) {
            let id = Self.closures.count
            
            Self.closures[callee, default: []].append({ buffer, startIndex in
                let arguments = try TermDecoder().decode(
                    ArgumentList<repeat each Argument>.self,
                    from: buffer,
                    startIndex: startIndex
                ).arguments
                
                let result = try action(repeat each arguments)
                
                let buffer = ErlangTermBuffer()
                buffer.newWithVersion()
                
                var resultCount = 0
                repeat ((each Result).self, resultCount += 1)
                
                switch resultCount {
                case 0:
                    buffer.encode(atom: "ok")
                case 1:
                    let encoder = TermEncoder()
                    encoder.options.includeVersion = false
                    for result in repeat (each result) {
                        buffer.append(try encoder.encode(result))
                    }
                default:
                    buffer.encode(tupleHeader: resultCount)
                    
                    let encoder = TermEncoder()
                    encoder.options.includeVersion = false
                    for result in repeat (each result) {
                        buffer.append(try encoder.encode(result))
                    }
                }
                
                return buffer
            })
            
            let annotation = 1
            
            var argumentCount = 0
            repeat ((each Argument).self, argumentCount += 1)
            
            // `free_fun` frees the buffer for us, so we can create the buffer
            // here without the `ErlangTermBuffer` and not worry about lifecycle
            var freeVars = ei_x_buff()
            ei_x_new(&freeVars)
            
            // {annotation, bindings, local handler, external handler, %{}, clauses}
            ei_x_encode_tuple_header(&freeVars, 6)
            ei_x_encode_long(&freeVars, annotation)
            
            ei_x_encode_map_header(&freeVars, 1) // bindings
            ei_x_encode_atom(&freeVars, "_@1") // pid
            var pid = callee.pid
            ei_x_encode_pid(&freeVars, &pid)
            
            // {:value, &elixir.eval_local_handler/2}
            ei_x_encode_tuple_header(&freeVars, 2)
            ei_x_encode_atom(&freeVars, "value")
            var eval_local_handler = Function("elixir", "eval_local_handler", 2)
            ei_x_encode_fun(&freeVars, &eval_local_handler.fun)
            
            // {:value, &elixir.eval_external_handler/3}
            ei_x_encode_tuple_header(&freeVars, 2)
            ei_x_encode_atom(&freeVars, "value")
            var eval_external_handler = Function("elixir", "eval_external_handler", 3)
            ei_x_encode_fun(&freeVars, &eval_external_handler.fun)
            
            ei_x_encode_map_header(&freeVars, 0) // %{}
            
            ei_x_encode_list_header(&freeVars, 1) // clauses

            // encode Erlang AST for function clause
            func tupleAST(arity: Int, _ build: () -> ()) {
                ei_x_encode_tuple_header(&freeVars, 3)
                ei_x_encode_atom(&freeVars, "tuple")
                ei_x_encode_long(&freeVars, annotation)
                ei_x_encode_list_header(&freeVars, arity) // elements
                build()
                ei_x_encode_empty_list(&freeVars) // elements tail
            }
            
            func atomAST( _ atom: String) {
                ei_x_encode_tuple_header(&freeVars, 3)
                ei_x_encode_atom(&freeVars, "atom")
                ei_x_encode_long(&freeVars, annotation)
                ei_x_encode_atom(&freeVars, atom)
            }
            
            func varAST(_ name: String) {
                ei_x_encode_tuple_header(&freeVars, 3)
                ei_x_encode_atom(&freeVars, "var")
                ei_x_encode_long(&freeVars, annotation)
                ei_x_encode_atom(&freeVars, name)
            }
            
            /// - Note: You must encode another term to add to the list
            func consHeaderAST(lhs: () -> ()) {
                ei_x_encode_tuple_header(&freeVars, 4)
                ei_x_encode_atom(&freeVars, "cons")
                ei_x_encode_long(&freeVars, annotation)
                lhs()
            }
            
            // {:clause, ANNO, pattern, guard, body}
            ei_x_encode_tuple_header(&freeVars, 5)

            ei_x_encode_atom(&freeVars, "clause") // clause
            ei_x_encode_long(&freeVars, annotation)
            // pattern
            if argumentCount == 0 {
                ei_x_encode_empty_list(&freeVars)
            } else {
                ei_x_encode_list_header(&freeVars, argumentCount)
                for argument in 0..<argumentCount {
                    varAST("_arg@\(argument)")
                }
                ei_x_encode_empty_list(&freeVars) // tail
            }
            ei_x_encode_empty_list(&freeVars) // guard

            // send(pid, {:fn, :hello})
            // receive do res -> res end
            ei_x_encode_list_header(&freeVars, 2) // body
            
            // send(pid, {:fn, :hello})
            ei_x_encode_tuple_header(&freeVars, 4)
            ei_x_encode_atom(&freeVars, "call")
            ei_x_encode_long(&freeVars, annotation)
            
            ei_x_encode_tuple_header(&freeVars, 4)
            ei_x_encode_atom(&freeVars, "remote")
            ei_x_encode_long(&freeVars, annotation)
            
            atomAST("erlang")
            atomAST("send")
            
            ei_x_encode_list_header(&freeVars, 2) // args list
            
            varAST("_@1")
            // {:call, id, sender, [args...]}
            tupleAST(arity: 4) {
                atomAST("call")
                
                // {:integer, annotation, id}
                ei_x_encode_tuple_header(&freeVars, 3)
                ei_x_encode_atom(&freeVars, "integer")
                ei_x_encode_long(&freeVars, annotation)
                ei_x_encode_long(&freeVars, id)
                
                // self()
                ei_x_encode_tuple_header(&freeVars, 4)
                ei_x_encode_atom(&freeVars, "call")
                ei_x_encode_long(&freeVars, annotation)
                ei_x_encode_tuple_header(&freeVars, 4)
                ei_x_encode_atom(&freeVars, "remote")
                ei_x_encode_long(&freeVars, annotation)
                atomAST("erlang")
                atomAST("self")
                ei_x_encode_empty_list(&freeVars)
                
                // args
                if argumentCount == 0 {
                    ei_x_encode_tuple_header(&freeVars, 2)
                    ei_x_encode_atom(&freeVars, "nil")
                    ei_x_encode_long(&freeVars, annotation)
                } else {
                    for argument in 0..<argumentCount {
                        consHeaderAST {
                            varAST("_arg@\(argument)")
                        }
                    }
                    // cons tail
                    ei_x_encode_tuple_header(&freeVars, 2)
                    ei_x_encode_atom(&freeVars, "nil")
                    ei_x_encode_long(&freeVars, annotation)
                }
            }
            
            ei_x_encode_empty_list(&freeVars) // args list tail
            
            // receive do res -> res end
            ei_x_encode_tuple_header(&freeVars, 3)
            ei_x_encode_atom(&freeVars, "receive")
            ei_x_encode_long(&freeVars, annotation)
            
            ei_x_encode_list_header(&freeVars, 1) // clauses
            
            // {:clause, annotation, bindings, guard, body}
            ei_x_encode_tuple_header(&freeVars, 5)
            ei_x_encode_atom(&freeVars, "clause") // clause
            ei_x_encode_long(&freeVars, annotation)
            
            ei_x_encode_list_header(&freeVars, 1) // pattern
            varAST("_res@1")
            ei_x_encode_empty_list(&freeVars) // pattern tail
            
            ei_x_encode_empty_list(&freeVars) // guard
            
            ei_x_encode_list_header(&freeVars, 1) // body
            varAST("_res@1")
            ei_x_encode_empty_list(&freeVars) // receive body tail
            
            ei_x_encode_empty_list(&freeVars) // receive clauses tail
            
            ei_x_encode_empty_list(&freeVars) // body tail

            ei_x_encode_empty_list(&freeVars) // clauses tail

            self.fun = erlang_fun(
                arity: argumentCount,
                module: "erl_eval".tuple(),
                type: EI_FUN_CLOSURE,
                u: erlang_fun.__Unnamed_union_u(closure: erlang_fun.__Unnamed_union_u.__Unnamed_struct_closure(
                    md5: "".tuple(),
                    index: Int(pid.num),
                    old_index: 0,
                    uniq: id,
                    n_free_vars: 1,
                    pid: pid,
                    free_var_len: Int(freeVars.buffsz),
                    free_vars: freeVars.buff
                ))
            )
        }
        
        public init(
            _ module: String,
            _ function: String,
            _ arity: Int
        ) {
            self.fun = erlang_fun(
                arity: arity,
                module: module.tuple(),
                type: EI_FUN_EXPORT,
                u: erlang_fun.__Unnamed_union_u(
                    exprt: erlang_fun.__Unnamed_union_u.__Unnamed_struct_exprt(
                        func: strdup(function),
                        func_allocated: 0
                    )
                )
            )
        }
        
        deinit {
            free_fun(&fun)
        }
        
        public static func == (lhs: Function, rhs: Function) -> Bool {
            lhs.hashValue == rhs.hashValue
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(fun.arity)
            hasher.combine(fun.type)
            hasher.combine(Array(tuple: fun.module, start: \.0))
            
            hasher.combine(fun.u.closure.free_var_len)
            hasher.combine(fun.u.closure.free_vars)
            hasher.combine(fun.u.closure.index)
            hasher.combine(fun.u.closure.n_free_vars)
            hasher.combine(fun.u.closure.old_index)
            hasher.combine(fun.u.closure.old_index)
            hasher.combine(fun.u.closure.uniq)
            hasher.combine(Array(tuple: fun.u.closure.md5, start: \.0))
            hasher.combine(PID(pid: fun.u.closure.pid))
            
            hasher.combine(fun.u.exprt.func)
            hasher.combine(fun.u.exprt.func_allocated)
        }
    }
    
    func encode(to buffer: inout ErlangTermBuffer, initializeBuffer: Bool = true) throws {
        if initializeBuffer {
            guard buffer.newWithVersion()
            else { throw TermError.encodingError }
        }
        
        switch self {
        case let .int(int):
            guard buffer.encode(long: int)
            else { throw TermError.encodingError }
        case let .double(double):
            guard buffer.encode(double: double)
            else { throw TermError.encodingError }
        case let .atom(atom):
            guard buffer.encode(atom: strdup(atom))
            else { throw TermError.encodingError }
        case var .ref(ref):
            guard buffer.encode(ref: &ref.ref)
            else { throw TermError.encodingError }
        case var .port(port):
            guard buffer.encode(port: &port.port)
            else { throw TermError.encodingError }
        case var .pid(pid):
            guard buffer.encode(pid: &pid.pid)
            else { throw TermError.encodingError }
        case let .tuple(terms):
            guard buffer.encode(tupleHeader: terms.count)
            else { throw TermError.encodingError }
            for term in terms {
                try term.encode(to: &buffer, initializeBuffer: false)
            }
        case let .list(list) where list.isEmpty:
            guard buffer.encode(listHeader: list.count)
            else { throw TermError.encodingError }
        case let .list(list):
            guard buffer.encode(listHeader: list.count)
            else { throw TermError.encodingError }
            for term in list {
                try term.encode(to: &buffer, initializeBuffer: false)
            }
            guard buffer.encodeEmptyList()
            else { throw TermError.encodingError }
        case let .binary(binary):
            guard binary.withUnsafeBytes({ pointer in
                buffer.encode(binary: pointer.baseAddress!, len: Int32(pointer.count))
            })
            else { throw TermError.encodingError }
        case let .bitstring(bitstring):
            guard bitstring.withUnsafeBytes({ pointer in
                buffer.encode(bitstring: pointer.baseAddress!, bitoffs: 0, bits: pointer.count * UInt8.bitWidth)
            })
            else { throw TermError.encodingError }
        case var .function(function):
            guard buffer.encode(fun: &function.fun)
            else { throw TermError.encodingError }
        case let .map(map):
            guard buffer.encode(mapHeader: map.count)
            else { throw TermError.encodingError }
            for (key, value) in map {
                try key.encode(to: &buffer, initializeBuffer: false)
                try value.encode(to: &buffer, initializeBuffer: false)
            }
        case let .string(string):
            guard buffer.encode(string: strdup(string))
            else { throw TermError.encodingError }
        }
    }
    
    public init(
        from buffer: ErlangTermBuffer
    ) throws {
        var index: Int32 = 0
        
        var version: Int32 = 0
        buffer.decode(version: &version, index: &index)
//        guard ei_decode_version(buffer.buff, &index, &version) == 0
//        else { throw TermError.decodingError(.missingVersion) }
        
        func decodeNext() throws -> Self {
            var type: UInt32 = 0
            var size: Int32 = 0
            buffer.getType(type: &type, size: &size, index: &index)
            
            switch Character(UnicodeScalar(type)!) {
            case "a", "b": // integer
                var int: Int = 0
                guard buffer.decode(long: &int, index: &index)
                else { throw TermError.decodingError(.badTerm) }
                return .int(int)
            case "c", "F": //  float
                var double: Double = 0
                guard buffer.decode(double: &double, index: &index)
                else { throw TermError.decodingError(.badTerm) }
                return .double(double)
            case "d", "s", "v": // atom
                var atom: [CChar] = [CChar](repeating: 0, count: Int(MAXATOMLEN))
                guard buffer.decode(atom: &atom, index: &index)
                else { throw TermError.decodingError(.badTerm) }
                return .atom(String(cString: atom))
            case "e", "r", "Z": // ref
                var ref: erlang_ref = erlang_ref()
                guard buffer.decode(ref: &ref, index: &index)
                else { throw TermError.decodingError(.badTerm) }
                return .ref(.init(ref: ref))
            case "f", "Y", "x": // port
                var port: erlang_port = erlang_port()
                guard buffer.decode(port: &port, index: &index)
                else { throw TermError.decodingError(.badTerm) }
                return .port(.init(port: port))
            case "g", "X": // pid
                var pid = erlang_pid()
                guard buffer.decode(pid: &pid, index: &index)
                else { throw TermError.decodingError(.badTerm) }
                return .pid(.init(pid: pid))
            case "h", "i": // tuple
                var arity: Int32 = 0
                guard buffer.decode(tupleHeader: &arity, index: &index)
                else { throw TermError.decodingError(.badTerm) }
                return .tuple(try (0..<arity).map { _ in
                    try decodeNext()
                })
            case "k": // string
                var string: UnsafeMutablePointer<CChar> = .allocate(capacity: Int(size) + 1)
                defer { string.deallocate() }
                guard buffer.decode(string: string, index: &index)
                else { throw TermError.decodingError(.badTerm) }
                return .string(String(cString: string))
            case "l": // list
                var arity: Int32 = 0
                guard buffer.decode(listHeader: &arity, index: &index)
                else { throw TermError.decodingError(.badTerm) }
                let elements = try (0..<arity).map { _ in
                    try decodeNext()
                }
                // empty list header at the end
                guard buffer.decode(listHeader: &arity, index: &index),
                      arity == 0
                else { throw TermError.decodingError(.missingListEnd) }
                return .list(elements)
            case "j": // empty list
                var arity: Int32 = 0
                guard buffer.decode(listHeader: &arity, index: &index),
                      arity == 0
                else { throw TermError.decodingError(.badTerm) }
                return .list([])
            case "m": // binary
                var binary: UnsafeMutableRawPointer = .allocate(byteCount: Int(size), alignment: 0)
                var length: Int = 0
                guard buffer.decode(binary: binary, len: &length, index: &index)
                else { throw TermError.decodingError(.badTerm) }
                return .binary(Data(bytes: binary, count: length))
            case "M": // bit binary
                var pointer: UnsafePointer<CChar>?
                var bitOffset: UInt32 = 0
                var bits: Int = 0
                guard buffer.decode(bitstring: &pointer, bitoffsp: &bitOffset, nbitsp: &bits, index: &index)
                else { throw TermError.decodingError(.badTerm) }
                guard bitOffset == 0
                else { throw TermError.decodingError(.unsupportedBitOffset(bitOffset)) }
                return .bitstring(pointer.map {
                    Data(bytes: $0, count: bits / UInt8.bitWidth)
                } ?? Data())
            case "p", "u", "q": // function
                var fun: erlang_fun = erlang_fun()
                guard buffer.decode(fun: &fun, index: &index)
                else { throw TermError.decodingError(.badTerm) }
                return .function(.init(fun: fun))
            case "t": // map
                var arity: Int32 = 0
                guard buffer.decode(mapHeader: &arity, index: &index)
                else { throw TermError.decodingError(.badTerm) }
                return .map(Dictionary(uniqueKeysWithValues: try (0..<arity).map { _ in
                    let pair = (try decodeNext(), try decodeNext())
                    return pair
                }))
            case let type:
                throw TermError.decodingError(.unknownType(type))
            }
        }
        
        self = try decodeNext()
    }
    
    public func makeBuffer() throws -> ErlangTermBuffer {
        var buffer = ErlangTermBuffer()
        
        try encode(to: &buffer)
        
        return buffer
    }
    
    enum TermError: Error {
        case encodingError
        case decodingError(DecodingError)
        
        enum DecodingError {
            case missingVersion
            case badTerm
            case unknownType(Character)
            
            case unsupportedBitOffset(UInt32)
            
            case missingListEnd
        }
    }
}
