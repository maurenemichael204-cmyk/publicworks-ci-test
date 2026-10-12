import Foundation

// UIDEnvelope / UIDEntry 保留定义：后端若以后续提供 /uids 接口可直接复用，
// 当前"自己 UID 版"客户端已不再调用该接口。
struct UIDEnvelope: Decodable {
    let uids: [UIDEntry]
}

struct UIDEntry: Decodable {
    let uid: String
}

struct WorksEnvelope: Decodable {
    let uid: String
    let fetchedAt: String
    let works: [PublicWork]
}

struct PublicWork: Decodable, Identifiable {
    let id: String
    let title: String
    let url: String
    let publishedAt: String
}

struct QueryItem: Identifiable {
    var id: String { uid }
    let uid: String
    var fetchedAt: String = ""
    var works: [PublicWork] = []
    var error: String?
}

struct LogEntry: Identifiable {
    let id = UUID()
    let time = Date()
    let message: String
}
