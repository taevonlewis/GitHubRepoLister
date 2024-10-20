struct Repository: Codable, Sendable {
    let id: Int
    let name: String
    let fullName: String
    let privateRepo: Bool
    let description: String?
    let htmlUrl: String
    let url: String
    let forks: Int
    let openIssues: Int
    let watchers: Int
    let language: String?
    let visibility: String
    let archived: Bool
    let owner: Owner

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case fullName = "full_name"
        case privateRepo = "private"
        case description
        case htmlUrl = "html_url"
        case url
        case forks
        case openIssues = "open_issues"
        case watchers
        case language
        case visibility
        case archived
        case owner
    }
}

struct Owner: Codable {
    let login: String
    let id: Int
    let avatarUrl: String
    let htmlUrl: String
    let type: String

    enum CodingKeys: String, CodingKey {
        case login
        case id
        case avatarUrl = "avatar_url"
        case htmlUrl = "html_url"
        case type
    }
}