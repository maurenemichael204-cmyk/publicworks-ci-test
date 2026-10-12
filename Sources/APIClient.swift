import Foundation

enum APIError: LocalizedError {
    case invalidBaseURL
    case invalidUID
    case httpStatus(Int)
    case nonHTTPResponse

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Base URL 必须是有效的 HTTPS 地址。"
        case .invalidUID:
            return "UID 格式不符合允许的字符范围（仅限字母、数字、下划线、连字符）。"
        case .httpStatus(let code):
            return "服务器返回 HTTP \(code)。"
        case .nonHTTPResponse:
            return "服务器响应不是有效的 HTTP 响应。"
        }
    }
}

@MainActor
final class APIClient {
    private let baseURL: URL
    private let token: String
    private let minimumInterval: TimeInterval = 1
    private var lastRequestAt: Date?
    private let session: URLSession

    init(baseURLString: String, token: String) throws {
        guard let url = URL(string: baseURLString),
              url.scheme?.lowercased() == "https",
              url.host != nil else {
            throw APIError.invalidBaseURL
        }

        self.baseURL = url
        self.token = token

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    deinit {
        session.invalidateAndCancel()
    }

    /// 查询指定 UID 的公开作品（UID 由用户自行配置，查询自己的账号）。
    func fetchWorks(uid: String) async throws -> WorksEnvelope {
        let trimmed = uid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.range(
            of: #"^[A-Za-z0-9_-]+$"#,
            options: .regularExpression
        ) != nil else {
            throw APIError.invalidUID
        }

        return try await get(path: ["users", trimmed, "public-works"])
    }

    private func get<T: Decodable>(path: [String]) async throws -> T {
        if let last = lastRequestAt {
            let remaining = minimumInterval - Date().timeIntervalSince(last)
            if remaining > 0 {
                try await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }
        }
        try Task.checkCancellation()

        var url = baseURL
        for component in path {
            url.appendPathComponent(component)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        // 节流间隔从请求完成起算。
        defer { lastRequestAt = Date() }

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.nonHTTPResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            // 不读取或记录响应正文，避免意外暴露敏感信息。
            throw APIError.httpStatus(http.statusCode)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}
