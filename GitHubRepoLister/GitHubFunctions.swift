////
//  GitHubTool.swift
//  GitHubRepoLister
//
//  Created by TaeVon Lewis on 10/20/24.
//


import Foundation
import ArgumentParser

struct GitHubTool: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "A GitHub management tool.",
        subcommands: [ListRepos.self, DeleteRepo.self, AddAccount.self, SwitchAccount.self]
    )

    struct ListRepos: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "List repositories for a user.")
        
        @Argument(help: "GitHub username.")
        var username: String
        
        func run() throws {
            let token = KeychainHelper.getToken(account: username) ?? ""
            let repos = fetchRepositoriesSync(for: username, token: token)
            displayRepositories(repos)
        }
    }

    struct DeleteRepo: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Delete a repository.")
        
        @Argument(help: "GitHub username.")
        var username: String
        
        @Argument(help: "Repository to delete.")
        var repo: String
        
        @Flag(help: "Dry run mode.")
        var dryRun = false
        
        func run() throws {
            let token = KeychainHelper.getToken(account: username) ?? ""
            deleteRepository(owner: username, repo: repo, token: token, dryRun: dryRun)
        }
    }

    struct AddAccount: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Add a new GitHub account.")
        
        @Argument(help: "GitHub username.")
        var username: String
        
        @Argument(help: "GitHub personal access token.")
        var token: String
        
        func run() throws {
            KeychainHelper.saveToken(account: username, token: token)
            print("Account \(username) added successfully.")
        }
    }

    struct SwitchAccount: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Switch between GitHub accounts.")
        
        @Argument(help: "GitHub username.")
        var username: String
        
        func run() throws {
            // Logic to switch active account (handled internally based on username argument)
            print("Switched to account: \(username)")
        }
    }
}

GitHubTool.main()
