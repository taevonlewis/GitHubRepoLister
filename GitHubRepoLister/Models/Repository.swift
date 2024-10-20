////
//  Repository.swift
//  GitHubRepoLister
//
//  Created by TaeVon Lewis on 10/19/24.
//


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
    
    // Custom init if needed to handle decoding more carefully
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        fullName = try container.decode(String.self, forKey: .fullName)
        privateRepo = try container.decode(Bool.self, forKey: .privateRepo)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        htmlUrl = try container.decode(String.self, forKey: .htmlUrl)
        url = try container.decode(String.self, forKey: .url)
        forks = try container.decode(Int.self, forKey: .forks)
        openIssues = try container.decode(Int.self, forKey: .openIssues)
        watchers = try container.decode(Int.self, forKey: .watchers)
        language = try container.decodeIfPresent(String.self, forKey: .language)
        visibility = try container.decode(String.self, forKey: .visibility)
        archived = try container.decode(Bool.self, forKey: .archived)
        owner = try container.decode(Owner.self, forKey: .owner)
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
