////
//  main.swift
//  GitHubRepoLister
//
//  Created by TaeVon Lewis on 10/19/24.
//

import Foundation
import ArgumentParser

struct GitHubTool: ParsableCommand {
    static let repoLister = GitHubRepoLister()
    static var currentAccount: String? = KeychainHelper.getActiveAccount()

    static let configuration = CommandConfiguration(
        commandName: "ghtool",
        abstract: "A GitHub management tool.",
        subcommands: [ListRepos.self, DeleteRepo.self, AddAccount.self, RemoveAccount.self, SwitchAccount.self, ChangeVisibility.self],
        defaultSubcommand: Interactive.self
    )

    struct Interactive: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Enter interactive mode.")
        
        func run() throws {
            var shouldContinue = true
            
            while shouldContinue {
                if let currentAccount = GitHubTool.currentAccount {
                    print("Active account: \(currentAccount)")
                    print("Enter command (list-repos, delete-repo, change-visibility, add-account, remove-account, switch-account) or 'wq' to quit:")
                } else {
                    print("No account added. Enter command (add-account, wq to quit):")
                }
                
                if let input = readLine() {
                    do {
                        try repoLister.checkForQuit(input: input)
                    } catch ProgramExitError.userQuit {
                        print("Exiting program by user command.")
                        shouldContinue = false
                        continue
                    }
                    
                    switch input {
                    case "list-repos":
                        guard let username = GitHubTool.currentAccount else {
                            print("No account added. Please add an account first.")
                            continue
                        }
                        let token = KeychainHelper.getToken(account: username) ?? ""
                        let (ownedRepos, collaboratorRepos) = repoLister.fetchRepositoriesSync(for: username, token: token)
                        repoLister.displayRepositories(ownedRepos: ownedRepos, collaboratorRepos: collaboratorRepos)
                    case "delete-repo":
                        guard let username = GitHubTool.currentAccount else {
                            print("No account added. Please add an account first.")
                            continue
                        }
                        let token = KeychainHelper.getToken(account: username) ?? ""
                        let (ownedRepos, collaboratorRepos) = repoLister.fetchRepositoriesSync(for: username, token: token)
                        repoLister.displayRepositories(ownedRepos: ownedRepos, collaboratorRepos: collaboratorRepos)

                        // Prompt for repository selection
                        let selectedRepos = try repoLister.promptForInitialRepositorySelection(ownedRepos: ownedRepos, collaboratorRepos: collaboratorRepos)

                        if selectedRepos.isEmpty {
                            print("No repositories selected.")
                            continue
                        }

                        // Confirm and delete the selected repositories
                        if repoLister.confirmAction("Would you like to delete the selected repositories?") {
                            Task {
                                await repoLister.batchDeleteRepositories(repos: selectedRepos, token: token, dryRun: false)

                                // Ensure the success message appears after the operation completes
                                print("Successfully deleted the selected repositories.")
                            }
                        }
                    case "change-visibility":
                        guard let username = GitHubTool.currentAccount else {
                            print("No account added. Please add an account first.")
                            continue
                        }
                        let token = KeychainHelper.getToken(account: username) ?? ""
                        print("Do you want to set repositories to private or public? (Enter 'private' or 'public'):")

                        if let visibilityInput = readLine(), let isPrivate = visibilityInput == "private" ? true : visibilityInput == "public" ? false : nil {
                            let (ownedRepos, collaboratorRepos) = repoLister.fetchRepositoriesSync(for: username, token: token)
                            repoLister.displayRepositories(ownedRepos: ownedRepos, collaboratorRepos: collaboratorRepos)

                            // Prompt for initial selection of either owned or collaborator repositories
                            let selectedRepos = try repoLister.promptForInitialRepositorySelection(ownedRepos: ownedRepos, collaboratorRepos: collaboratorRepos)

                            if selectedRepos.isEmpty {
                                print("No repositories selected.")
                                continue
                            }

                            // Display only once for confirmation
                            if repoLister.confirmAction("Would you like to change the visibility of these repositories?") {
                                Task {
                                    await repoLister.batchUpdateVisibility(repos: selectedRepos, isPrivate: isPrivate, token: token, dryRun: false)

                                    // Ensure success message appears after the operation completes
                                    print("Successfully updated the visibility of the selected repositories.")
                                }
                            }
                        } else {
                            print("Invalid visibility input. Please enter 'private' or 'public'.")
                        }
                    case "add-account":
                        print("Enter GitHub username:")
                        let username = readLine() ?? ""
                        print("Enter personal access token:")
                        let token = readLine() ?? ""
                        KeychainHelper.saveToken(account: username, token: token)
                        GitHubTool.currentAccount = username
                        KeychainHelper.setActiveAccount(username)
                        print("Account \(username) added successfully.")
                    case "remove-account":
                        guard let username = GitHubTool.currentAccount else {
                            print("No account to remove. Please add an account first.")
                            continue
                        }
                        KeychainHelper.removeToken(account: username)
                        GitHubTool.currentAccount = nil
                        KeychainHelper.removeActiveAccount()
                        print("Account \(username) removed successfully.")
                    case "switch-account":
                        print("Enter GitHub username to switch to:")
                        let username = readLine() ?? ""
                        if KeychainHelper.getToken(account: username) != nil {
                            GitHubTool.currentAccount = username
                            KeychainHelper.setActiveAccount(username)
                            print("Switched to account: \(username)")
                        } else {
                            print("No token found for \(username). Please add the account first.")
                        }
                    case "wq":
                        shouldContinue = false
                    default:
                        print("Unknown command. Please try again.")
                    }
                }
            }
        }
    }
    
    struct ListRepos: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "List repositories for a user.")
        
        func run() throws {
            guard let username = GitHubTool.currentAccount else {
                print("No account added. Please add an account first.")
                return
            }
            let token = KeychainHelper.getToken(account: username) ?? ""
            let (ownedRepos, collaboratorRepos) = repoLister.fetchRepositoriesSync(for: username, token: token)
            repoLister.displayRepositories(ownedRepos: ownedRepos, collaboratorRepos: collaboratorRepos)
        }
    }

    struct ChangeVisibility: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Change the visibility of repositories.")
        
        @Flag(inversion: .prefixedNo, help: "Set repositories to private visibility")
        var setPrivate: Bool
        
        @Flag(inversion: .prefixedNo, help: "Set repositories to public visibility")
        var setPublic: Bool
        
        func run() throws {
            guard let username = GitHubTool.currentAccount else {
                print("No account added. Please add an account first.")
                return
            }
            let token = KeychainHelper.getToken(account: username) ?? ""
            let (ownedRepos, collaboratorRepos) = repoLister.fetchRepositoriesSync(for: username, token: token)
            repoLister.displayRepositories(ownedRepos: ownedRepos, collaboratorRepos: collaboratorRepos)
            
            // Ensure the prompt for initial selection is handled properly
            let selectedRepos = try repoLister.promptForInitialRepositorySelection(ownedRepos: ownedRepos, collaboratorRepos: collaboratorRepos)
            
            if selectedRepos.isEmpty {
                print("No repositories selected.")
                return
            }
            
            print("Selected repositories:")
            repoLister.displayRepositories(ownedRepos: selectedRepos, collaboratorRepos: [])
            
            let isPrivate = setPrivate
            if repoLister.confirmAction("Would you like to change the visibility of these repositories?") {
                Task {
                    await repoLister.batchUpdateVisibility(repos: selectedRepos, isPrivate: isPrivate, token: token, dryRun: false)
                }
            }
        }
    }
    
    struct DeleteRepo: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Delete a repository.")
        
        @Argument(help: "Repository to delete.")
        var repo: String
        
        @Flag(help: "Dry run mode.")
        var dryRun = false
        
        func run() throws {
            guard let username = GitHubTool.currentAccount else {
                print("No account added. Please add an account first.")
                return
            }
            let token = KeychainHelper.getToken(account: username) ?? ""
            let (ownedRepos, collaboratorRepos) = repoLister.fetchRepositoriesSync(for: username, token: token)
            repoLister.displayRepositories(ownedRepos: ownedRepos, collaboratorRepos: collaboratorRepos)
            
            let selectedRepos = try repoLister.promptForInitialRepositorySelection(ownedRepos: ownedRepos, collaboratorRepos: collaboratorRepos)
            if selectedRepos.isEmpty {
                print("No repositories selected.")
                return
            }
            
            print("Selected repositories:")
            repoLister.displayRepositories(ownedRepos: selectedRepos, collaboratorRepos: collaboratorRepos)
            
            if repoLister.confirmAction("Would you like to delete the selected repositories?") {
                Task {
                    await repoLister.batchDeleteRepositories(repos: selectedRepos, token: token, dryRun: dryRun)
                }
            }
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
            GitHubTool.currentAccount = username
            KeychainHelper.setActiveAccount(username)
            print("Account \(username) added successfully.")
        }
    }

    struct RemoveAccount: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Remove an existing GitHub account.")
        
        func run() throws {
            guard let username = GitHubTool.currentAccount else {
                print("No account to remove.")
                return
            }
            KeychainHelper.removeToken(account: username)
            GitHubTool.currentAccount = nil
            KeychainHelper.removeActiveAccount()
            print("Account \(username) removed successfully.")
        }
    }
    
    struct SwitchAccount: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Switch between GitHub accounts.")
        
        @Argument(help: "GitHub username.")
        var username: String
        
        func run() throws {
            if KeychainHelper.getToken(account: username) != nil {
                GitHubTool.currentAccount = username
                KeychainHelper.setActiveAccount(username)
                print("Switched to account: \(username)")
            } else {
                print("No token found for \(username). Please add the account first.")
            }
        }
    }
}

// Custom main() function for interactive mode
func main() {
    if CommandLine.argc == 1 {
        do {
            try GitHubTool.Interactive().run()
        } catch ProgramExitError.userQuit {
            print("Program exited by user.")
        } catch {
            print("Failed to start interactive mode: \(error)")
        }
    } else {
        GitHubTool.main()
    }
}

// Run the tool
main()
