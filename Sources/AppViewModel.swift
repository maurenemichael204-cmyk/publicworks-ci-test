import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    @Published var baseURL: String
    @Published var token: String
    @Published var uid: String          // 自己的 UID
    @Published var pollMinutes = 5
    @Published var items: [QueryItem] = []
    @Published var logs: [LogEntry] = []
    @Published var loggingEnabled = false
    @Published private(set) var isRunning = false
    @Published private(set) var isRefreshing = false
    @Published var configurationError: String?
    @Published var runtimeError: String?

    private var client: APIClient?
    private var worker: Task<Void, Never>?
    private var generation = 0

    init() {
        baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") ?? ""
        token = KeychainStore.read()
        uid = UserDefaults.standard.string(forKey: "ownUID") ?? ""
        let saved = UserDefaults.standard.integer(forKey: "pollMinutes")
        pollMinutes = saved < 1 ? 5 : saved
        configureClient()
    }

    func saveConfiguration() {
        guard let url = URL(string: baseURL),
              url.scheme?.lowercased() == "https",
              url.host != nil else {
            configurationError = APIError.invalidBaseURL.localizedDescription
            return
        }

        guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            configurationError = "Token 不能为空。"
            return
        }

        let trimmedUID = uid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUID.isEmpty,
              trimmedUID.range(of: #"^[A-Za-z0-9_-]+$"#,
                               options: .regularExpression) != nil else {
            configurationError = "UID 不能为空，且仅限字母、数字、下划线、连字符。"
            return
        }

        do {
            try KeychainStore.save(token)
            UserDefaults.standard.set(baseURL, forKey: "apiBaseURL")
            UserDefaults.standard.set(trimmedUID, forKey: "ownUID")
            UserDefaults.standard.set(pollMinutes, forKey: "pollMinutes")
            uid = trimmedUID
            configureClient()
            configurationError = nil
            log("配置已保存")
        } catch {
            configurationError = "无法安全保存 Token。"
        }
    }

    func start() {
        guard !isRunning else { return }
        saveConfiguration()
        guard client != nil, configurationError == nil else { return }

        runtimeError = nil
        isRunning = true
        worker = Task {
            while !Task.isCancelled {
                await self.refreshOnce()
                let seconds = max(1, self.pollMinutes) * 60
                try? await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        worker?.cancel()
        worker = nil
        isRunning = false
        generation += 1
        log("自动查询已停止")
    }

    func refreshOnce() async {
        guard !isRefreshing else { return }
        guard let client else {
            configurationError = "请先保存有效配置。"
            return
        }
        let targetUID = uid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !targetUID.isEmpty else {
            configurationError = "请先填写自己的 UID。"
            return
        }

        isRefreshing = true
        let myGeneration = generation
        defer { isRefreshing = false }

        do {
            let result = try await client.fetchWorks(uid: targetUID)
            guard myGeneration == generation else { return }

            var seenWorkIDs = Set<String>()
            let works = result.works.filter { seenWorkIDs.insert($0.id).inserted }

            items = [QueryItem(uid: targetUID,
                               fetchedAt: result.fetchedAt,
                               works: works,
                               error: nil)]
            log("作品查询成功：\(works.count) 条")
            runtimeError = nil
        } catch {
            guard myGeneration == generation else { return }
            if !items.isEmpty, items[0].uid == targetUID {
                items[0].error = error.localizedDescription
            } else {
                items = [QueryItem(uid: targetUID, error: error.localizedDescription)]
            }
            runtimeError = error.localizedDescription
            log("作品查询失败：\(error.localizedDescription)")
        }
    }

    func clearLocalData() {
        stop()
        generation += 1
        KeychainStore.delete()
        UserDefaults.standard.removeObject(forKey: "apiBaseURL")
        UserDefaults.standard.removeObject(forKey: "ownUID")
        UserDefaults.standard.removeObject(forKey: "pollMinutes")
        baseURL = ""
        token = ""
        uid = ""
        pollMinutes = 5
        items = []
        logs = []
        configurationError = nil
        runtimeError = nil
        client = nil
        // 不重置 isRefreshing：在途任务的 defer 负责复位。
    }

    private func configureClient() {
        do {
            client = try APIClient(baseURLString: baseURL, token: token)
            configurationError = nil
        } catch {
            client = nil
        }
    }

    private func log(_ message: String) {
        guard loggingEnabled else { return }
        logs.insert(LogEntry(message: message), at: 0)
        if logs.count > 100 { logs.removeLast() }
    }
}
