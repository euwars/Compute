//
//  Types.swift
//  
//
//  Created by Andrew Barba on 1/12/22.
//

public typealias WasiHandle = Int32

public enum WasiStatus: Int32, Error, CaseIterable {
    case ok = 0
    case genericError
    case invalidArgument
    case badDescriptor
    case bufferTooSmall
    case unsupported
    case wrongAlignment
    case httpParserError
    case httpUserError
    case httpIncomplete
    case none
    case httpHeadTooLarge
    case httpInvalidStatus
}

public enum HttpVersion: Int32 {
    case http0_9 = 0
    case http1_0
    case http1_1
    case h2
    case h3
}

public enum HttpMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case options = "OPTIONS"
    case query = "QUERY"
}

public typealias HttpStatus = Int32

public enum BodyWriteEnd: Int32 {
    case back = 0
    case front
}

public enum IpAddress {
    case v4(String)
    case v6(String)

    public var stringValue: String {
        switch self {
        case .v4(let text):
            return text
        case .v6(let text):
            return text
        }
    }
}

public typealias BodyHandle = WasiHandle

public typealias RequestHandle = WasiHandle

public typealias ResponseHandle = WasiHandle

public typealias PendingRequestHandle = WasiHandle

public typealias EndpointHandle = WasiHandle

public typealias DictionaryHandle = WasiHandle

public typealias MultiValueCursor = Int32

public typealias MultiValueCursorResult = Int64

public typealias CacheOverrideTag = Int32

extension CacheOverrideTag {
    public static let none: Self = 0x1
    public static let pass: Self = 0x2
    public static let ttl: Self = 0x4
    public static let staleWhileRevalidate: Self = 0x8
    public static let pci: Self = 0x10
}

public enum CachePolicy {
    case origin
    case pass
    case ttl(seconds: Int, staleWhileRevalidate: Int)
}

public typealias HeaderCount = Int32

public typealias IsDone = Int32

public typealias DoneIndex = Int32

public enum ContentEncodings: Int32 {
    case gzip = 1
}

internal let maxBufferLength = 8192

internal let maxHeaderLength = 4096

internal let maxMethodLength = 1024

internal let maxUriLength = 4096

internal let maxDictionaryEntryLength = 8000
