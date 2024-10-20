////
//  GitHubTool.swift
//  GitHubRepoLister
//
//  Created by TaeVon Lewis on 10/20/24.
//


import Foundation
import ArgumentParser

struct GitHubRepoLister: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "A tool to list GitHub repositories for a given user, including private repositories."
    )
    
    @Argument(help: "The GitHub username to fetch repositories for.")
    var username: String

    @Option(name: [.customLong("token")], help: "Your GitHub personal access token.")
    var token: String?

    @Flag(inversion: .prefixedNo, help: "Simulate the actions without making actual changes.")
    var dryRun: Bool = false
    
    func run() throws {
        let token = token ?? KeychainHelper.getToken(account: username)

        guard let validToken = token else {
            print("No token found for \(username). Please provide a token.")
            return
        }

        KeychainHelper.saveToken(account: username, token: validToken)

        // Fetch repositories synchronously and separate them
        let (ownedRepos, collaboratorRepos) = fetchRepositoriesSync(for: username, token: validToken)

        // Display the fetched repositories
        displayRepositories(ownedRepos: ownedRepos, collaboratorRepos: collaboratorRepos)

        // Prompt for selecting owned or collaborator repos
        var selectedRepos: [Repository] = []
        do {
            selectedRepos = try promptForInitialRepositorySelection(ownedRepos: ownedRepos, collaboratorRepos: collaboratorRepos)
        } catch ProgramExitError.userQuit {
            print("Exiting program by user command.")
            return
        }

        if selectedRepos.isEmpty {
            print("No repositories selected.")
            return
        }

        // No need to display repositories again here, as they were already shown during selection
        // Prompt for visibility change
        print("Do you want to set the selected repositories to private or public? (Enter 'private' or 'public'):")
        guard let visibilityInput = readLine(), let isPrivate = visibilityInput == "private" ? true : visibilityInput == "public" ? false : nil else {
            print("Invalid visibility input. Please enter 'private' or 'public'.")
            return
        }

        // Confirm visibility change action
        if confirmAction("Would you like to change the visibility of these repositories?") {
            Task {
                await batchUpdateVisibility(repos: selectedRepos, isPrivate: isPrivate, token: validToken, dryRun: dryRun)

                // Move this print statement inside the Task to ensure it occurs after success
                print("Successfully updated the visibility of the selected repositories.")
            }
        }
    }
    
    func fetchRepositoriesSync(for username: String, token: String) -> (ownedRepos: [Repository], collaboratorRepos: [Repository]) {
        var ownedRepos: [Repository] = []
        var collaboratorRepos: [Repository] = []
        let dispatchGroup = DispatchGroup()
        var page = 1
        var keepFetching = true
        
        repeat {
            dispatchGroup.enter()
            fetchRepositories(for: username, token: token, page: page, dispatchGroup: dispatchGroup) { repos in
                for repo in repos {
                    if repo.owner.login == username {
                        ownedRepos.append(repo)
                    } else {
                        collaboratorRepos.append(repo)
                    }
                }
                if repos.isEmpty {
                    keepFetching = false
                }
                page += 1
            }
            dispatchGroup.wait()
        } while keepFetching && page <= 100
        
        return (ownedRepos, collaboratorRepos)
    }
    
    func fetchRepositories(for username: String, token: String, page: Int, dispatchGroup: DispatchGroup, completion: @escaping ([Repository]) -> Void) {
        let apiURL = "https://api.github.com/user/repos?per_page=100&page=\(page)"
        
        guard let url = URL(string: apiURL) else {
            print("Invalid URL.")
            dispatchGroup.leave()
            completion([])
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { dispatchGroup.leave() }
            
            if let error = error {
                print("Error fetching repositories: \(error.localizedDescription)")
                completion([])
                return
            }
            
            guard let data = data else {
                print("No data received.")
                completion([])
                return
            }
            
            do {
                let repos = try JSONDecoder().decode([Repository].self, from: data)
                completion(repos)
            } catch {
                print("Error decoding repositories: \(error.localizedDescription)")
                completion([])
            }
        }
        
        task.resume()
    }
    
    func displayRepositories(ownedRepos: [Repository], collaboratorRepos: [Repository]) {
        if ownedRepos.isEmpty && collaboratorRepos.isEmpty {
            print("No repositories found.")
            return
        }
        
        if !ownedRepos.isEmpty {
            print("My Repositories:")
            for (index, repo) in ownedRepos.enumerated() {
                let visibility = repo.visibility.capitalized
                print("\(index + 1). \(repo.name) - \(visibility) (Archived: \(repo.archived))")
            }
        }
        
        if !collaboratorRepos.isEmpty {
            print("\nCollaborator Repositories:")
            for (index, repo) in collaboratorRepos.enumerated() {
                let visibility = repo.visibility.capitalized
                print("\(index + 1). \(repo.name) - \(visibility) (Archived: \(repo.archived))")
            }
        }
    }
    
    func promptForInitialRepositorySelection(ownedRepos: [Repository], collaboratorRepos: [Repository]) throws -> [Repository] {
        print("Would you like to select from 'owned' repositories or 'collaborator' repositories? (Enter 'owned' or 'collaborator'):")
        guard let choice = readLine()?.lowercased() else {
            print("Invalid input. Please try again.")
            return try promptForInitialRepositorySelection(ownedRepos: ownedRepos, collaboratorRepos: collaboratorRepos)
        }

        if choice == "owned" {
            return try promptForRepositorySelection(ownedRepos: ownedRepos, collaboratorRepos: [])
        } else if choice == "collaborator" {
            return try promptForRepositorySelection(ownedRepos: [], collaboratorRepos: collaboratorRepos)
        } else {
            print("Invalid choice. Please enter 'owned' or 'collaborator'.")
            return try promptForInitialRepositorySelection(ownedRepos: ownedRepos, collaboratorRepos: collaboratorRepos)
        }
    }
    
    func promptForAdditionalRepositorySelection(ownedRepos: [Repository], collaboratorRepos: [Repository], previouslySelectedRepos: [Repository]) -> [Repository] {
        let unselectedOwnedRepos = ownedRepos.filter { repo in
            !previouslySelectedRepos.contains { $0.name == repo.name }
        }
        let unselectedCollaboratorRepos = collaboratorRepos.filter { repo in
            !previouslySelectedRepos.contains { $0.name == repo.name }
        }

        if unselectedOwnedRepos.isEmpty && unselectedCollaboratorRepos.isEmpty {
            print("No additional repositories available for selection.")
            return []
        }

        print("Would you like to select from the 'remaining' owned or collaborator repositories? (Enter 'owned' or 'collaborator'):")
        if let choice = readLine()?.lowercased() {
            if choice == "owned" {
                return try! promptForRepositorySelection(ownedRepos: unselectedOwnedRepos, collaboratorRepos: [])
            } else if choice == "collaborator" {
                return try! promptForRepositorySelection(ownedRepos: [], collaboratorRepos: unselectedCollaboratorRepos)
            }
        }
        return []
    }
    
    func promptForRepositorySelection(ownedRepos: [Repository], collaboratorRepos: [Repository]) throws -> [Repository] {
        let repos = ownedRepos + collaboratorRepos
        print("Select repository numbers separated by commas (e.g., 1,3,5) or use a keyword. Type ':wq' to quit:")

        if let input = readLine() {
            try checkForQuit(input: input)
            
            let numbers = input.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }

            if !numbers.isEmpty {
                let selectedRepos = numbers.compactMap { index in
                    if index > 0 && index <= repos.count {
                        return repos[index - 1]
                    } else {
                        print("Invalid selection: \(index) is out of range.")
                        return nil
                    }
                }

                if !selectedRepos.isEmpty {
                    print("Selected repositories:")
                    displayRepositories(ownedRepos: selectedRepos, collaboratorRepos: [])
                }
                return selectedRepos
            } else {
                let keyword = input.lowercased()
                let matchingRepos = repos.filter { $0.name.lowercased().contains(keyword) }

                if matchingRepos.isEmpty {
                    print("No repositories found with keyword: \(input)")
                    return []
                } else {
                    print("Selected repositories:")
                    displayRepositories(ownedRepos: matchingRepos, collaboratorRepos: [])
                    return matchingRepos
                }
            }
        }

        return []
    }
    
    func deleteRepository(owner: String, repo: String, token: String, dryRun: Bool) async throws {
        if dryRun {
            print("[DRY RUN] Would delete repository: \(repo)")
            return
        }
        
        let urlString = "https://api.github.com/repos/\(owner)/\(repo)"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "Invalid URL", code: 400, userInfo: nil)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("Response status code: \(httpResponse.statusCode)")
            
            if let responseBody = String(data: data, encoding: .utf8) {
                print("Response body: \(responseBody)")
            }
            
            if httpResponse.statusCode == 204 {
                print("Repository \(repo) deleted successfully.")
            } else if httpResponse.statusCode == 403 {
                throw NSError(domain: "Failed to delete repository: \(repo) - Must have admin rights", code: 403, userInfo: nil)
            } else {
                throw NSError(domain: "Failed to delete repository \(repo)", code: httpResponse.statusCode, userInfo: nil)
            }
        }
    }
    
    func batchDeleteRepositories(repos: [Repository], token: String, dryRun: Bool) async {
        await withTaskGroup(of: Void.self) { taskGroup in
            for repo in repos {
                taskGroup.addTask {
                    do {
                        try await deleteRepository(owner: repo.owner.login, repo: repo.name, token: token, dryRun: dryRun)
                        print("Successfully deleted \(repo.name)")
                    } catch {
                        print("Failed to delete \(repo.name): \(error.localizedDescription)")
                    }
                }
            }
        }
        // Print success message after all operations complete
        if repos.count > 1 {
            print("All selected repositories have been processed for deletion.")
        }
    }
    
    func updateRepositoryVisibility(owner: String, repo: Repository, isPrivate: Bool, token: String, dryRun: Bool) async throws {
        if repo.fork {
            print("Repository \(repo.name) is a fork and cannot have its visibility changed.")
            return
        }

        if dryRun {
            print("[DRY RUN] Would update visibility for repository: \(repo.name) to \(isPrivate ? "private" : "public")")
            return
        }

        let urlString = "https://api.github.com/repos/\(owner)/\(repo.name)"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "Invalid URL", code: 400, userInfo: nil)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("token \(token)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = ["private": isPrivate]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode != 200 {
                let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
                print("Failed to update repository visibility. Status code: \(httpResponse.statusCode)")
                print("Response body: \(responseBody)")
                throw NSError(domain: "Update failed", code: httpResponse.statusCode, userInfo: nil)
            }
        }
    }
    
    func batchUpdateVisibility(repos: [Repository], isPrivate: Bool, token: String, dryRun: Bool) async {
        await withTaskGroup(of: Void.self) { taskGroup in
            for repo in repos {
                taskGroup.addTask {
                    do {
                        try await updateRepositoryVisibility(owner: repo.owner.login, repo: repo, isPrivate: isPrivate, token: token, dryRun: dryRun)
                        print("Successfully updated \(repo.name)")
                    } catch {
                        print("Failed to update \(repo.name): \(error.localizedDescription)")
                    }
                }
            }
        }
        // Print success message after all operations complete
        if repos.count > 1 {
            print("All selected repositories have been processed for visibility update.")
        }
    }
    
    func confirmAction(_ message: String) -> Bool {
        print("\(message) (y/n): ")
        
        if let response = readLine(), response.lowercased() == "y" {
            return true
        }
        return false
    }
    
    func checkForQuit(input: String?) throws {
        guard let input = input else { return }
        if input.trimmingCharacters(in: .whitespacesAndNewlines) == ":wq" {
            throw ProgramExitError.userQuit
        }
    }
}
