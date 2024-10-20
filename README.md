# GitHubRepoLister

A command-line tool to manage your GitHub repositories, including listing, deleting, changing visibility, and batch operations for repositories. This tool supports multiple GitHub accounts, interactive mode, and efficient token management.

## Table of Contents
- [Installation](#installation)
- [Setting Up GitHub Token](#setting-up-github-token)
- [Interactive Mode](#interactive-mode)
- [Commands](#commands)
  - [List Repositories](#list-repositories)
  - [Delete Repository](#delete-repository)
  - [Change Repository Visibility](#change-repository-visibility)
  - [Batch Operations](#batch-operations)
- [Logging and Debugging](#logging-and-debugging)

## Installation

**Download from GitHub**
1. Go to the Releases page.
2. Download the .exe file for your OS.
3. Run the binary directly from your terminal.

**Via Homebrew**

You can install the CLI tool using Homebrew if it’s available:

`brew install your-repo/tap/githubrepolister`

To uninstall:

`brew uninstall your-repo/tap/githubrepolister`

## Setting Up GitHub Token

To interact with the GitHub API, you will need a Personal Access Token (PAT). Follow these steps to create and set it up with GitHubRepoLister:

1. Go to GitHub Token Generation.
2. Click Generate new token.
3. Select the required scopes:
	 **repo:** Full control of private repositories.
	**delete_repo:** Ability to delete repositories.
6. Copy the generated token.

**To store the token in the CLI tool:**

`githubrepolister add-account`

You will be prompted to enter your GitHub username and the token. The token will be stored securely using Keychain.

## Interactive Mode

By default, GitHubRepoLister operates in interactive mode. In this mode, you are prompted to enter commands interactively without needing to pass flags or arguments on the command line. Here's how it works:

After launching the tool, you will see:

```bash
Active account: <username>
Enter command (list-repos, delete-repo, change-visibility, add-account, remove-account, switch-account) or 'wq' to quit:
```


You can choose commands interactively:
- `list-repos` to see all your repositories.
- `delete-repo` to delete repositories interactively.
- `change-visibility` to modify repository visibility.
- `wq` to exit the program.

The tool will prompt you through each step.

**Example Session**

Active account: tatortots
Enter command (list-repos, delete-repo, change-visibility, add-account, remove-account, switch-account) or 'wq' to quit:
```bash
> list-repos
My Repositories:
1. repo1 - Public (Archived: false)
2. repo2 - Private (Archived: true)
Enter command (list-repos, delete-repo, change-visibility, add-account, remove-account, switch-account) or 'wq' to quit:
```

## Commands

### List Repositories

You can list all the repositories for the active GitHub account, both owned and collaborator repositories.

Usage:

`githubrepolister list-repos`

Example Output:

```bash
My Repositories:
1. repo1 - Public (Archived: false)
2. repo2 - Private (Archived: true)

Collaborator Repositories:
1. repoA - Public (Archived: false)
2. repoB - Private (Archived: false)
```

### Delete Repository

The delete-repo command deletes a specified repository. The tool will prompt you to select repositories and confirm deletion.

Usage:

`githubrepolister delete-repo`

You will be asked to select repositories by number or name from the list and then confirm the deletion.

Example:

`Would you like to delete the selected repositories? (y/n):`

Options:

`--dry-run`: Simulate the delete operation without making any actual changes.

### Change Repository Visibility

The change-visibility command allows you to change a repository from public to private or vice versa. You can select multiple repositories for batch visibility changes.

Usage:

`githubrepolister change-visibility`

You will be prompted to select repositories and set their visibility (private/public).

Options:

`--set-private`: Make the selected repositories private.
`--set-public`: Make the selected repositories public.

Example:

`Would you like to set these repositories to 'private' or 'public'?:`

### Batch Operations

You can perform batch operations for multiple repositories at once, including batch deletion or batch visibility changes.

**Batch Delete**

To delete multiple repositories interactively:

`githubrepolister delete-repo`

You will be prompted to select repositories and confirm deletion:

`Select repository numbers separated by commas (e.g., 1,3,5) or use a keyword. Type ':wq' to quit:`

**Batch Change Visibility**

Similarly, you can change the visibility of multiple repositories interactively:

`githubrepolister change-visibility`

You will be prompted to select repositories and set their visibility.

## Logging and Debugging

To troubleshoot issues or log operations, you can enable logging.

Enabling Logging:

Logs are generated for API requests, operations performed (e.g., delete, change visibility), and errors encountered during execution. You can specify the log level by setting an environment variable:

`export GITHUBREPOTOOL_LOG_LEVEL=DEBUG`

Log File Location:

Logs are stored in the /logs directory within the tool’s execution directory.

Debugging Tips:

1. Ensure that your GitHub token has the correct permissions.
2. Check your internet connection for issues.
3. Verify that you are not hitting GitHub’s API rate limit.
