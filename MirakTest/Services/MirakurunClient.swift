import Foundation

enum MirakurunError: LocalizedError {
    case invalidBaseURL
    case httpStatus(Int)
    case unsupportedServer

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Mirakurun の URL が正しくありません"
        case let .httpStatus(code):
            return "HTTP \(code)"
        case .unsupportedServer:
            return "Mirakurun 互換サーバーとして認識できませんでした"
        }
    }
}

struct MirakurunClient {
    let baseURL: URL
    let userAgent: String

    private let session: URLSession

    init(baseURLString: String, userAgent: String) throws {
        var trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        // デスクトップ版の設定は "http://host:40772/api" 形式なので、/api が無ければ補う
        if !trimmed.hasSuffix("/api") {
            trimmed += "/api"
        }
        guard let url = URL(string: trimmed), let scheme = url.scheme, ["http", "https"].contains(scheme), url.host != nil else {
            throw MirakurunError.invalidBaseURL
        }
        baseURL = url
        self.userAgent = userAgent

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.httpAdditionalHeaders = ["User-Agent": userAgent]
        session = URLSession(configuration: configuration)
    }

    private func get(_ path: String, query: [URLQueryItem] = []) async throws -> Data {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query
        }
        let (data, response) = try await session.data(from: components.url!)
        if let http = response as? HTTPURLResponse, !(200 ..< 300).contains(http.statusCode) {
            throw MirakurunError.httpStatus(http.statusCode)
        }
        return data
    }

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem] = [], as _: T.Type) async throws -> T {
        try JSONDecoder().decode(T.self, from: try await get(path, query: query))
    }

    /// 接続先サーバーの種類とバージョンを判定する
    func checkServer() async throws -> (MirakurunCompatibility, String?) {
        let statusData = try await get("status")
        let status = try? JSONDecoder().decode(MirakurunStatus.self, from: statusData)
        let versionObject = try? JSONSerialization.jsonObject(with: try await get("version"), options: [.fragmentsAllowed])

        // mirakc の status の返り値は {}
        if let dict = try? JSONSerialization.jsonObject(with: statusData) as? [String: Any], dict.isEmpty, let versionObject {
            if let version = versionObject as? String {
                return (.mirakc, version)
            }
            return (.mirakc, (versionObject as? [String: Any])?["current"] as? String)
        }
        if let version = status?.version {
            if (versionObject as? [String: Any])?["server"] as? String == "mahiron" {
                return (.mahiron, version)
            }
            return (.mirakurun, version)
        }
        throw MirakurunError.unsupportedServer
    }

    func services() async throws -> [Service] {
        try await get("services", as: LossyArray<Service>.self).elements
    }

    func logo(of service: Service) async throws -> Data {
        try await get("services/\(service.id)/logo")
    }

    func programs(networkId: Int? = nil, serviceId: Int? = nil) async throws -> [Program] {
        var query = [URLQueryItem]()
        if let networkId {
            query.append(URLQueryItem(name: "networkId", value: String(networkId)))
        }
        if let serviceId {
            query.append(URLQueryItem(name: "serviceId", value: String(serviceId)))
        }
        return try await get("programs", query: query, as: LossyArray<Program>.self).elements
    }

    func streamURL(of service: Service) -> URL {
        baseURL.appendingPathComponent("services/\(service.id)/stream")
    }
}

/// 一部の要素がデコードできなくても、残りの要素は取得できる配列
/// サーバー実装 (Mirakurun / mirakc 等) の差異で 1 件不正なだけで番組表全体が消えるのを防ぐ
private struct LossyArray<Element: Decodable>: Decodable {
    var elements: [Element]

    /// 型を問わず 1 要素を読み飛ばす
    private struct Skip: Decodable {
        init(from _: Decoder) throws {}
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var elements = [Element]()
        while !container.isAtEnd {
            if try container.decodeNil() {
                continue
            }
            if let element = try? container.decode(Element.self) {
                elements.append(element)
            } else if (try? container.decode(Skip.self)) == nil {
                // 読み飛ばせない場合に無限ループしないよう打ち切る
                break
            }
        }
        self.elements = elements
    }
}
