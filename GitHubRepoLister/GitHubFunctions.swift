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

        if token == nil {
            print("No token found for \(username). Please provide a token.")
            return
        }

        if let tokenFromCLI = token {
            KeychainHelper.saveToken(account: username, token: tokenFromCLI)
        }

        // Fetch repositories synchronously
        let repos = self.fetchRepositoriesSync(for: username, token: token!)
        if repos.isEmpty {
            print("No repositories available for selection.")
            return
        }

        self.displayRepositories(repos)
        
        // Prompt for repository selection
        let selectedRepos = promptForRepositorySelection(repos: repos)

        // Simulate or perform operations
        if confirmAction("Would you like to delete the selected repositories?") {
            let dispatchGroup = DispatchGroup()

            for repo in selectedRepos {
                dispatchGroup.enter()
                deleteRepository(owner: repo.owner.login, repo: repo.name, token: token!, dryRun: dryRun) { result in
                    switch result {
                    case .success():
                        print("Repository \(repo.name) deleted successfully.")
                    case .failure(let error):
                        print("Failed to delete repository \(repo.name): \(error.localizedDescription)")
                    }
                    dispatchGroup.leave() // Ensure dispatchGroup is notified after the operation completes
                }
            }
            
            // Wait for all deletions to complete before exiting the program
            dispatchGroup.wait()
        }
    }

    func fetchRepositoriesSync(for username: String, token: String) -> [Repository] {
        var allRepos: [Repository] = []
        let dispatchGroup = DispatchGroup()
        var page = 1
        var keepFetching = true
        
        repeat {
            dispatchGroup.enter()
            fetchRepositories(for: username, token: token, page: page, dispatchGroup: dispatchGroup) { repos in
                allRepos.append(contentsOf: repos)
                // Stop if no more repos are returned
                if repos.isEmpty {
                    keepFetching = false
                }
                page += 1
            }
            dispatchGroup.wait()
        } while keepFetching && page <= 100 // Limit to 100 pages for safety
        
        return allRepos
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
    
    func displayRepositories(_ repos: [Repository]) {
        if repos.isEmpty {
            print("No repositories found.")
            return
        }
        
        for (index, repo) in repos.enumerated() {
            let visibility = repo.visibility.capitalized
            print("\(index + 1). \(repo.name) - \(visibility) (Archived: \(repo.archived))")
            print("Repo Info: Name: \(repo.name), Visibility: \(repo.visibility), Archived: \(repo.archived)")
        }
    }
    
     func promptForRepositorySelection(repos: [Repository]) -> [Repository] {
        print("Select repository numbers separated by commas (e.g., 1,3,5) or use a keyword:")

        if let input = readLine() {
            let numbers = input.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            
            // If numbers were entered, select repos by their number
            if !numbers.isEmpty {
                // Ensure the selected numbers are within the range of available repositories
                return numbers.compactMap { index in
                    if index > 0 && index <= repos.count {
                        return repos[index - 1]
                    } else {
                        print("Invalid selection: \(index) is out of range.")
                        return nil
                    }
                }
            } else {
                // Otherwise, filter repositories by keyword
                return repos.filter { $0.name.contains(input) }
            }
        }

        return []
    }
    
     func deleteRepository(owner: String, repo: String, token: String, dryRun: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        if dryRun {
            print("[DRY RUN] Would delete repository: \(repo)")
            completion(.success(())) // Simulate success
            return
        }

        let urlString = "https://api.github.com/repos/\(owner)/\(repo)"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "Invalid URL", code: 400, userInfo: nil)))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("token \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("Response status code: \(httpResponse.statusCode)")
                
                if let responseData = data, let responseBody = String(data: responseData, encoding: .utf8) {
                    print("Response body: \(responseBody)")
                }

                if httpResponse.statusCode == 204 {
                    completion(.success(()))
                } else if httpResponse.statusCode == 403 {
                    print("Error: Must have admin rights to delete the repository \(repo)")
                    completion(.failure(NSError(domain: "Failed to delete repository \(repo) - Status code: \(httpResponse.statusCode)", code: httpResponse.statusCode, userInfo: nil)))
                } else {
                    completion(.failure(NSError(domain: "Failed to delete repository \(repo) - Status code: \(httpResponse.statusCode)", code: httpResponse.statusCode, userInfo: nil)))
                }
            }
        }.resume()
    }
    
     func updateRepositoryVisibility(owner: String, repo: String, isPrivate: Bool, token: String, dryRun: Bool) async throws {
        if dryRun {
            print("[DRY RUN] Would update visibility for repository: \(repo) to \(isPrivate ? "private" : "public")")
            return
        }

        let urlString = "https://api.github.com/repos/\(owner)/\(repo)"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "Invalid URL", code: 400, userInfo: nil)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("token \(token)", forHTTPHeaderField: "Authorization")

        let body = ["private": isPrivate]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw NSError(domain: "Update failed", code: 500, userInfo: nil)
        }
    }
    
     func batchUpdateVisibility(repos: [Repository], isPrivate: Bool, token: String, dryRun: Bool) async {
        await withTaskGroup(of: Void.self) { taskGroup in
            for repo in repos {
                taskGroup.addTask {
                    do {
                        try await updateRepositoryVisibility(owner: repo.owner.login, repo: repo.name, isPrivate: isPrivate, token: token, dryRun: dryRun)
                        print("Successfully updated \(repo.name)")
                    } catch {
                        print("Failed to update \(repo.name)")
                    }
                }
            }
        }
    }
    
     func confirmAction(_ message: String) -> Bool {
        print("\(message) (y/n): ")
        
        if let response = readLine(), response.lowercased() == "y" {
            return true
        }
        return false
    }
    
    // Function to extract the next page URL from the "Link" header
     func getNextPageURL(from linkHeader: String) -> URL? {
        let links = linkHeader.components(separatedBy: ",")
        for link in links {
            let components = link.components(separatedBy: ";")
            if components.count == 2,
               components[1].trimmingCharacters(in: .whitespacesAndNewlines) == "rel=\"next\"" {
                let urlString = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
                return URL(string: urlString)
            }
        }
        return nil
    }
}
