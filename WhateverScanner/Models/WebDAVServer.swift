import Foundation

struct WebDAVServer: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var url: String
    var username: String
    var password: String

    init(id: UUID = UUID(), name: String, url: String, username: String, password: String) {
        self.id = id
        self.name = name
        self.url = url
        self.username = username
        self.password = password
    }
}
