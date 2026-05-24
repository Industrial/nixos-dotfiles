# pi-mcp-beads Plugin

This plugin serves as an MCP server that encapsulates all of the `bd` (Beads) CLI commands and their functionalities as tools. This allows other agents or systems to interact with Beads commands programmatically through the MCP protocol.

## Beads CLI Overview

Beads is a command-line interface for issue tracking and project management, designed to streamline workflows, manage dependencies, and integrate with version control systems. It focuses on providing a lightweight yet powerful way to handle issues, visualize project structure, and maintain a clean codebase.

### Core Concepts:

*   **Issues (Beads)**: The fundamental unit for tracking tasks, features, bugs, or any work item. Issues have unique IDs, statuses, types, and can be linked to form complex project structures.
*   **Dependencies**: Issues can have explicit dependencies on each other, forming directed acyclic graphs (DAGs) that help visualize and manage workflows.
*   **Version Control Integration**: Deep integration with Git and Dolt (a versioned SQL database) allows for tracking changes, managing branches, and maintaining historical data for issues.
*   **MCP (Model Context Protocol)**: Pi's framework for enabling agents to discover and use tools, including those exposed by MCP servers. This plugin acts as an MCP server for Beads commands.

### Commands and Subcommands:

This section provides a comprehensive explanation of all `bd` commands and their subcommands.

#### Working With Issues:

*   **`bd assign <issue_id...> --actor <actor>`**
    *   **Purpose**: Assigns one or more issues to a specific user (actor).
    *   **How it works**: Updates the `assignee` field of the specified issues.
    *   **When to use**: To delegate tasks or track who is responsible for an issue.
*   **`bd children <issue_id>`**
    *   **Purpose**: Lists all direct child issues of a given parent issue.
    *   **How it works**: Queries the issue database for issues whose parent is specified by `issue_id`.
    *   **When to use**: To understand the breakdown of a larger task or epic.
*   **`bd close <issue_id...>`**
    *   **Purpose**: Closes one or more issues.
    *   **How it works**: Changes the status of the specified issues to a "closed" state.
    *   **When to use**: When an issue is resolved or no longer needs to be tracked.
*   **`bd comment <issue_id> [--actor <actor>] [--body <body_text>] [--file <file_path>]`**
    *   **Purpose**: Adds a comment to an issue.
    *   **How it works**: Appends new text or content from a file as a comment to the specified issue.
    *   **When to use**: To add discussion, provide updates, or share context on an issue.
*   **`bd comments <issue_id> [--limit <N>]`**
    *   **Purpose**: Views or manages comments on an issue.
    *   **How it works**: Retrieves and displays all comments associated with an issue, optionally limited by count.
    *   **When to use**: To review the discussion history of an issue.
*   **`bd create [--title <title>] [--type <type>] [--description <desc>] [--parent <issue_id>] [--body <body_text>] [--file <file_path>] [--markdown <markdown_content>] [--json <json_content>] [--actor <actor>] [--batch]`**
    *   **Purpose**: Creates a new issue. Can be used interactively, from markdown, or from graph JSON.
    *   **How it works**: Parses input (title, description, type, parent, body, file content, markdown, or JSON) and creates a new issue in the database. Supports batch creation for efficiency.
    *   **When to use**: To log a new task, bug, feature request, or any work item. Use `--parent` for sub-tasks or `--batch` for multiple issues.
*   **`bd create-form`**
    *   **Purpose**: Creates a new issue using an interactive form.
    *   **How it works**: Launches an interactive TUI form to guide the user through creating an issue.
    *   **When to use**: For a user-friendly, guided issue creation process.
*   **`bd delete <issue_id...>`**
    *   **Purpose**: Deletes one or more issues and cleans up references.
    *   **How it works**: Permanently removes issues and updates any references (like dependencies or comments) pointing to them. Use with caution.
    *   **When to use**: When issues are accidentally created or are no longer needed and must be purged.
*   **`bd edit <issue_id> [--field <field_name>] [--value <new_value>] [--body <markdown_file>] [--file <file_path>] [-C <directory>]`**
    *   **Purpose**: Edits an issue field or its entire body.
    *   **How it works**: Allows modifying specific fields (like title, status, type) or the entire issue description by opening it in an editor or by providing a file path with new content.
    *   **When to use**: To update an existing issue's details, description, or status.
*   **`bd gate <issue_id...> --condition <condition> [--wait <duration>] [--action <action>]`**
    *   **Purpose**: Manages asynchronous coordination gates for issues.
    *   **How it works**: Sets up or manages conditions that must be met before an issue can proceed.
    *   **When to use**: For complex workflows where certain conditions must be satisfied before an issue can be progressed (e.g., all related tasks must be closed).
*   **`bd label <issue_id...> --add <label...> [--remove <label...>]`**
    *   **Purpose**: Manages labels attached to one or more issues.
    *   **How it works**: Adds or removes specified labels from issues. Labels are often used for categorization (e.g., "bug", "feature", "documentation").
    *   **When to use**: To categorize and filter issues.
*   **`bd link <issue_id1> <issue_id2> [--relation <relation>]`**
    *   **Purpose**: Links two issues together, typically defining a dependency.
    *   **How it works**: Creates a relationship between two issues. Common relations include "depends on", "blocks", "is blocked by", "duplicates", "supersedes".
    *   **When to use**: To explicitly define relationships between tasks, features, or bugs.
*   **`bd list [--query <query>] [--type <type>] [--status <status>] [--assignee <actor>] [--labels <label...>] [--sort <field>] [--reverse] [--limit <N>] [--format <format>]`**
    *   **Purpose**: Lists issues matching specified filters.
    *   **How it works**: Queries the issue database and returns a list of issues based on criteria like type, status, assignee, labels, and sort order. Supports various output formats.
    *   **When to use**: To get an overview of the project's issues, find specific issues, or generate reports.
*   **`bd merge-slot <issue_id...> --condition <condition> [--wait <duration>]`**
    *   **Purpose**: Manages "merge slot" gates for atomically processing multiple issues.
    *   **How it works**: Ensures that a set of issues are processed together in an atomic operation, preventing race conditions.
    *   **When to use**: For critical operations or workflows involving multiple issues that must be updated simultaneously.
*   **`bd note <issue_id> <note_text>`**
    *   **Purpose**: Appends a simple note to an issue.
    *   **How it works**: Similar to `comment`, but often used for more operational or metadata notes.
    *   **When to use**: For quick, informal updates or annotations on an issue.
*   **`bd priority <issue_id...> --priority <priority_level>`**
    *   **Purpose**: Sets the priority level of one or more issues.
    *   **How it works**: Assigns a priority (e.g., critical, high, medium, low) to issues, often affecting sorting or reporting.
    *   **When to use**: To indicate the relative importance of issues.
*   **`bd promote <issue_id>`**
    *   **Purpose**: Promotes a temporary "wisp" issue to a permanent "bead".
    *   **How it works**: Converts a transient issue into a tracked, permanent issue within the database.
    *   **When to use**: To make a quickly captured idea or task a formal part of the project backlog.
*   **`bd q`**
    *   **Purpose**: Quick capture: creates an issue and outputs only its ID.
    *   **How it works**: A shortcut to quickly create an issue with minimal input and get its identifier.
    *   **When to use**: For rapid logging of ideas or tasks without needing full details immediately.
*   **`bd query <query_string> [--type <type>] [--status <status>] [--assignee <actor>] [--labels <label...>] [--sort <field>] [--reverse] [--limit <N>]`**
    *   **Purpose**: Queries issues using a simple, structured query language.
    *   **How it works**: Allows complex filtering and sorting of issues using a domain-specific query syntax.
    *   **When to use**: For advanced filtering and retrieval of issues beyond basic `list` command options.
*   **`bd reopen <issue_id...>`**
    *   **Purpose**: Reopens one or more closed issues.
    *   **How it works**: Changes the status of closed issues back to an open state.
    *   **When to use**: If an issue was closed prematurely or needs further work.
*   **`bd search <text_query> [--limit <N>] [--type <type>] [--status <status>] [--assignee <actor>] [--labels <label...>]`**
    *   **Purpose**: Searches issues by a text query.
    *   **How it works**: Performs a full-text search across issue titles, descriptions, and comments.
    *   **When to use**: To find issues containing specific keywords or phrases.
*   **`bd set-state <issue_id...> --state <state_name> [--actor <actor>] [--comment <comment_text>]`**
    *   **Purpose**: Sets the operational state of an issue.
    *   **How it works**: Updates an issue's status and potentially creates an audit event.
    *   **When to use**: For structured workflow transitions that involve state changes and auditing.
*   **`bd show <issue_id> [--format <format>] [--comment-limit <N>] [--dependency-depth <N>] [--history] [--no-deps] [--no-comments]`**
    *   **Purpose**: Shows detailed information about a specific issue.
    *   **How it works**: Displays the issue's title, description, status, assignee, labels, comments, dependencies, and history. Various flags control the level of detail.
    *   **When to use**: To get a complete picture of a single issue, including its context and relationships.
*   **`bd state <dimension> [--list] [--query <query>]`**
    *   **Purpose**: Queries the current value of a state dimension across issues.
    *   **How it works**: Provides information about defined state dimensions (e.g., 'status', 'priority') and their current values in the database.
    *   **When to use**: To understand the range of possible states or the current distribution of states.
*   **`bd tag <issue_id...> --add <label...> [--remove <label...>]`**
    *   **Purpose**: Alias for `bd label`, adds or removes labels from issues.
    *   **How it works**: Same as `bd label`.
    *   **When to use**: To categorize and filter issues.
*   **`bd todo [--add <task_description>] [--list] [--complete <task_id>]`**
    *   **Purpose**: Manages TODO items associated with issues.
    *   **How it works**: A convenience wrapper for creating, listing, or marking as complete simple task issues.
    *   **When to use**: For simple, actionable sub-tasks directly tied to a main issue.
*   **`bd update <issue_id...> --field <field_name> --value <new_value>`**
    *   **Purpose**: Updates a specific field of one or more issues.
    *   **How it works**: Modifies a single field (e.g., status, priority) for specified issues. Use `bd edit` for more comprehensive changes.
    *   **When to use**: For quick, targeted updates to issue properties.

#### Views & Reports:

*   **`bd count [--query <query>] [--type <type>] [--status <status>] [--assignee <actor>] [--labels <label...>]`**
    *   **Purpose**: Counts issues matching specified filters.
    *   **How it works**: Returns the total number of issues that satisfy the given criteria.
    *   **When to use**: To quickly know the quantity of issues in a particular state or category.
*   **`bd diff [--base <commit>] [--head <commit>] [--path <path>] [--type <type>]`**
    *   **Purpose**: Shows changes between two commits, branches, or a commit and the working directory.
    *   **How it works**: Uses Git diff internally to highlight differences in code or configuration related to issues.
    *   **When to use**: To review changes associated with issues before they are committed or merged.
*   **`bd find-duplicates [--strategy <strategy>] [--threshold <N>] [--auto-merge]`**
    *   **Purpose**: Finds semantically similar issues using text analysis or AI.
    *   **How it works**: Analyzes issue titles, descriptions, and comments to identify potential duplicates. Can automatically merge them or flag them for review.
    *   **When to use**: To prevent duplicate work and consolidate similar requests.
*   **`bd history <issue_id>`**
    *   **Purpose**: Shows the version history for a specific issue.
    *   **How it works**: Displays a log of all changes made to an issue over time, including status changes, edits, and comments.
    *   **When to use**: To audit changes, understand the evolution of an issue, or revert to previous states.
*   **`bd lint [--fix]`**
    *   **Purpose**: Checks issues for missing template sections or format inconsistencies.
    *   **How it works**: Validates the structure and content of issue descriptions against predefined templates or linting rules. Can optionally attempt to fix issues.
    *   **When to use**: To ensure consistency and completeness in issue reporting.
*   **`bd stale [--query <query>] [--days <N>] [--assignee <actor>]`**
    *   **Purpose**: Shows issues that have not been updated recently.
    *   **How it works**: Identifies issues that have been inactive for a specified number of days.
    *   **When to use**: To find issues that might be forgotten or require follow-up.
*   **`bd status [--format <format>]`**
    *   **Purpose**: Shows an overview of the issue database, including statistics on types, statuses, and counts.
    *   **How it works**: Provides a summary dashboard of the project's issue landscape.
    *   **When to use**: To get a high-level understanding of the project's current state.
*   **`bd statuses [--list]`**
    *   **Purpose**: Lists all valid issue statuses defined in the system.
    *   **How it works**: Displays the available states that an issue can be in (e.g., open, in_progress, closed, resolved).
    *   **When to use**: To understand the workflow and available states.
*   **`bd types [--list]`**
    *   **Purpose**: Lists all valid issue types defined in the system.
    *   **How it works**: Displays the available categories for issues (e.g., feature, bug, task, chore).
    *   **When to use**: To understand the different kinds of work items that can be tracked.

#### Dependencies & Structure:

*   **`bd dep add <issue_id1> <issue_id2> [--type <type>]`**
    *   **Purpose**: Adds a dependency relationship between two issues.
    *   **How it works**: Records that `issue_id1` depends on `issue_id2`. Common types are `blocks`, `is_blocked_by`, `related`.
    *   **When to use**: To define explicit task sequences or relationships.
*   **`bd dep rm <issue_id1> <issue_id2> [--type <type>]`**
    *   **Purpose**: Removes a dependency relationship between two issues.
    *   **How it works**: Deletes the specified dependency link.
    *   **When to use**: When a dependency has been resolved or was incorrectly added.
*   **`bd dep list <issue_id>`**
    *   **Purpose**: Lists all dependencies for a given issue.
    *   **How it works**: Shows all direct and possibly indirect dependencies related to an issue.
    *   **When to use**: To understand the prerequisites or downstream effects of an issue.
*   **`bd duplicate <issue_id1> <issue_id2>`**
    *   **Purpose**: Marks `issue_id1` as a duplicate of `issue_id2`.
    *   **How it works**: Establishes a "duplicate" relationship and typically closes the first issue.
    *   **When to use**: When a new issue is found to be identical to an existing one.
*   **`bd duplicates [--auto-link]`**
    *   **Purpose**: Finds and optionally links or merges duplicate issues.
    *   **How it works**: Uses AI or text similarity to identify potential duplicates and can automate the linking process.
    *   **When to use**: To consolidate redundant issues.
*   **`bd epic <command>`**
    *   **Purpose**: Management commands for "epics" (large collections of related issues).
    *   **How it works**: Provides subcommands for creating, managing, and viewing epics. (Specific subcommands not detailed here but follow `bd epic --help`).
    *   **When to use**: To organize and track large initiatives composed of many smaller issues.
*   **`bd graph [--query <query>] [--depth <N>] [--format <format>] [--output <file_path>] [--focus <issue_id>]`**
    *   **Purpose**: Displays the issue dependency graph.
    *   **How it works**: Visualizes the relationships between issues as a directed graph, often output as text, JSON, or an image.
    *   **When to use**: To understand the complex interdependencies within a project.
*   **`bd supersede <issue_id1> <issue_id2>`**
    *   **Purpose**: Marks `issue_id1` as superseded by `issue_id2`.
    *   **How it works**: Establishes a "superseded" relationship, indicating that `issue_id2` replaces `issue_id1`.
    *   **When to use**: When a new issue replaces an older one, and the history should reflect this transition.
*   **`bd swarm <epic_id> <command>`**
    *   **Purpose**: Management commands for "swarms" (structured epics).
    *   **How it works**: Provides subcommands for managing swarms, which are typically used for structured epic rollouts. (Specific subcommands not detailed here but follow `bd swarm <epic_id> --help`).
    *   **When to use**: For managing complex, structured epic initiatives.

#### Sync & Data:

*   **`bd backup [--file <file_path>] [--format <format>]`**
    *   **Purpose**: Backs up the Beads database to a file.
    *   **How it works**: Exports the entire issue database (or parts of it) in a specified format (e.g., JSONL).
    *   **When to use**: For disaster recovery or migrating data.
*   **`bd branch <command>`**
    *   **Purpose**: Manages Git branches associated with issues or the database.
    *   **How it works**: Provides subcommands for listing, creating, or managing Git branches. (Specific subcommands not detailed here but follow `bd branch --help`).
    *   **When to use**: When integrating issue tracking with Git branching strategies.
*   **`bd export [--query <query>] [--format <format>] [--output <file_path>]`**
    *   **Purpose**: Exports issues to a file in a specified format (e.g., JSONL).
    *   **How it works**: Similar to `backup`, but can be selective based on queries.
    *   **When to use**: For sharing issue data or migrating to other systems.
*   **`bd federation <command>`**
    *   **Purpose**: Manages peer-to-peer federation with other Beads workspaces.
    *   **How it works**: Commands for setting up and managing distributed issue tracking across different instances. (Specific subcommands not detailed here but follow `bd federation --help`).
    *   **When to use**: For collaborative projects across multiple teams or organizations using Beads.
*   **`bd import [--file <file_path>] [--format <format>] [--stdin]`**
    *   **Purpose**: Imports issues from a file or standard input into the database.
    *   **How it works**: Reads issue data in a specified format and adds it to the current Beads database.
    *   **When to use**: For migrating issues from other systems or populating the database.
*   **`bd restore <issue_id> [--file <file_path>] [--commit <commit_hash>]`**
    *   **Purpose**: Restores the full history of a compacted issue from Dolt history.
    *   **How it works**: Reconstructs an issue's historical states from the underlying Dolt database.
    *   **When to use**: To recover past states of an issue or investigate historical changes within Dolt.
*   **`bd vc <command>`**
    *   **Purpose**: Performs Version Control operations related to Beads issues.
    *   **How it works**: Commands for interacting with Git or Dolt for versioned issue tracking. (Specific subcommands not detailed here but follow `bd vc --help`).
    *   **When to use**: When using Beads in conjunction with version control for code and issue history.

#### Setup & Configuration:

*   **`bd bootstrap [--force]`**
    *   **Purpose**: Non-destructive database setup for fresh clones and recovery.
    *   **How it works**: Initializes the necessary database schema and structure without removing existing data.
    *   **When to use**: When setting up Beads for the first time in a project or recovering a database.
*   **`bd config get <key>` / `bd config set <key> <value>`**
    *   **Purpose**: Manages configuration settings for Beads.
    *   **How it works**: Allows retrieval and modification of Beads settings, such as database paths, default actors, or AI integration preferences.
    *   **When to use**: To customize Beads behavior.
*   **`bd context`**
    *   **Purpose**: Shows the effective backend identity and repository context.
    *   **How it works**: Displays information about the current operating environment, including the database backend and Git repository details.
    *   **When to use**: To understand the current scope of Beads operations.
*   **`bd dolt --config <key> <value>`**
    *   **Purpose**: Configures settings specific to the Dolt database backend.
    *   **How it works**: Manages Dolt configuration parameters used by Beads.
    *   **When to use**: For advanced customization of the Dolt database.
*   **`bd forget <memory_name>`**
    *   **Purpose**: Removes a persistent memory entry.
    *   **How it works**: Deletes a stored piece of information from Beads' memory system.
    *   **When to use**: To clear out old or irrelevant stored facts.
*   **`bd hooks [--install] [--uninstall]`**
    *   **Purpose**: Manages Git hooks for integration with Beads.
    *   **How it works**: Installs or uninstalls Git hooks (e.g., pre-commit, post-commit) that integrate with Beads workflows.
    *   **When to use**: To automate Beads actions during Git operations.
*   **`bd human`**
    *   **Purpose**: Shows essential commands for human users.
    *   **How it works**: Provides a curated list of frequently used commands for manual operation.
    *   **When to use**: For quick reference for manual CLI users.
*   **`bd info`**
    *   **Purpose**: Shows detailed database information.
    *   **How it works**: Provides metadata about the current Beads database, such as schema version, size, and last commit.
    *   **When to use**: For troubleshooting or understanding the database state.
*   **`bd init [--force] [--db-path <path>] [--issue-prefix <prefix>] [--worktree-based]`**
    *   **Purpose**: Initializes Beads in the current directory.
    *   **How it works**: Sets up a new Beads database, configures issue tracking, and integrates with Git.
    *   **When to use**: When starting to use Beads in a new project.
*   **`bd kv <command>`**
    *   **Purpose**: Key-value store commands for managing arbitrary data.
    *   **How it works**: Provides subcommands for interacting with a simple key-value store. (Specific subcommands not detailed here but follow `bd kv --help`).
    *   **When to use**: For storing and retrieving small, arbitrary pieces of data.
*   **`bd memories [--search <query>] [--list]`**
    *   **Purpose**: Lists or searches persistent memories stored by Beads.
    *   **How it works**: Displays stored facts, insights, or context that agent sessions can recall.
    *   **When to use**: To review previously stored information.
*   **`bd onboard`**
    *   **Purpose**: Displays minimal snippet for agent instructions file.
    *   **How it works**: Outputs a concise set of instructions for an AI agent to use Beads effectively.
    *   **When to use**: To configure AI agents that need to interact with Beads.
*   **`bd prime`**
    *   **Purpose**: Outputs AI-optimized workflow context.
    *   **How it works**: Generates a distilled, AI-friendly summary of the current project state and relevant commands.
    *   **When to use**: To provide context to AI agents before they perform complex tasks.
*   **`bd quickstart`**
    *   **Purpose**: Provides a quick start guide for using Beads.
    *   **How it works**: A tutorial-like guide to get new users up and running quickly.
    *   **When to use**: For new users unfamiliar with Beads.
*   **`bd recall <memory_name>`**
    *   **Purpose**: Retrieves a specific stored memory.
    *   **How it works**: Fetches and displays the content of a named memory.
    *   **When to use**: To access specific facts or context previously stored.
*   **`bd remember <memory_name> <memory_content>`**
    *   **Purpose**: Stores a persistent memory entry.
    *   **How it works**: Saves a piece of information (content) under a given name for later recall.
    *   **When to use**: To store important facts, decisions, or context for future reference.
*   **`bd setup [--editor <editor_name>]`**
    *   **Purpose**: Sets up integration with AI editors.
    *   **How it works**: Configures Beads to work with specific IDEs or text editors for enhanced workflows.
    *   **When to use**: To improve the developer experience when using Beads alongside code editors.
*   **`bd where`**
    *   **Purpose**: Shows the active Beads database location and Git repository path.
    *   **How it works**: Reports the file system paths where Beads is operating.
    *   **When to use**: To confirm the Beads environment and data location.

#### Maintenance:

*   **`bd batch <command>`**
    *   **Purpose**: Runs multiple write operations in a single database transaction.
    *   **How it works**: Groups several database modifications into one atomic unit, improving efficiency and consistency.
    *   **When to use**: For performing multiple related updates without intermediate commits.
*   **`bd compact [--dry-run] [--force]`**
    *   **Purpose**: Squashes old Dolt commits to reduce history size.
    *   **How it works**: Optimizes the underlying Dolt database by reducing the number of historical commits.
    *   **When to use**: To manage database size and improve performance over time.
*   **`bd doctor [--fix]`**
    *   **Purpose**: Checks and fixes the Beads installation health.
    *   **How it works**: Diagnoses potential issues with the Beads installation and configuration, and can attempt to resolve them.
    *   **When to use**: As a first step for troubleshooting installation or configuration problems.
*   **`bd flatten [--dry-run] [--force]`**
    *   **Purpose**: Squashes all Dolt history into a single commit.
    *   **How it works**: Creates a new revision of the database where all history is collapsed into one commit. Use with extreme caution.
    *   **When to use**: For creating a clean baseline or troubleshooting advanced database issues.
*   **`bd gc [--dry-run] [--full]`**
    *   **Purpose**: Garbage collection for Beads: decays old issues, compacts Dolt commits, and runs Dolt GC.
    *   **How it works**: Cleans up obsolete data and optimizes storage.
    *   **When to use**: For routine maintenance to keep the database healthy and efficient.
*   **`bd migrate --to <version> [--from <version>]`**
    *   **Purpose**: Performs database migrations to upgrade or downgrade the schema.
    *   **How it works**: Manages schema changes in the Beads database.
    *   **When to use**: When upgrading or downgrading Beads versions that require database schema adjustments.
*   **`bd ping`**
    *   **Purpose**: Checks database connectivity and basic health.
    *   **How it works**: Verifies that Beads can connect to its database backend.
    *   **When to use**: For troubleshooting connectivity issues.
*   **`bd preflight`**
    *   **Purpose**: Shows a PR readiness checklist for changes.
    *   **How it works**: Checks if changes are ready for a pull request based on Beads-related criteria.
    *   **When to use**: To ensure that issues and associated work are properly prepared before submitting a PR.
*   **`bd prune [--days <N>] [--dry-run] [--force]`**
    *   **Purpose**: Deletes old closed issues to reclaim space and shrink exports.
    *   **How it works**: Removes historical closed issues that are no longer needed.
    *   **When to use**: To manage database size and improve performance.
*   **`bd purge [--days <N>] [--dry-run] [--force]`**
    *   **Purpose**: Deletes closed ephemeral issues to reclaim space.
    *   **How it works**: Similar to `prune`, but specifically targets "ephemeral" issue types.
    *   **When to use**: To clear out temporary or short-lived issue types.
*   **`bd rename-prefix <old_prefix> <new_prefix>`**
    *   **Purpose**: Renames the issue ID prefix for all issues in the database.
    *   **How it works**: Changes the scheme for issue identifiers (e.g., from "PROJ-123" to "NEWP-123").
    *   **When to use**: When rebranding or restructuring project identifiers.
*   **`bd rules [--audit] [--compact]`**
    *   **Purpose**: Audits and compacts Claude rules (related to AI-driven workflows).
    *   **How it works**: Manages AI-specific configuration rules.
    *   **When to use**: For managing AI-assisted features within Beads.
*   **`bd sql <sql_query>`**
    *   **Purpose**: Executes raw SQL against the Beads database.
    *   **How it works**: Allows direct interaction with the underlying SQL database. Use with caution and understanding of the schema.
    *   **When to use**: For advanced data inspection or manipulation requiring direct SQL access.
*   **`bd upgrade [--check] [--install] [--force]`**
    *   **Purpose**: Checks for and manages Beads version upgrades.
    *   **How it works**: Allows updating Beads to the latest version.
    *   **When to use**: To ensure you are using the latest features and bug fixes.
*   **`bd worktree <command>`**
    *   **Purpose**: Manages Git worktrees for parallel development related to issues.
    *   **How it works**: Provides subcommands for managing Git worktrees. (Specific subcommands not detailed here but follow `bd worktree --help`).
    *   **When to use**: When using parallel development strategies with Git worktrees and issue tracking.

#### Integrations & Advanced:

*   **`bd admin <command>`**
    *   **Purpose**: Administrative commands for advanced database maintenance.
    *   **How it works**: Provides low-level administrative tools for the Beads database. (Specific subcommands not detailed here but follow `bd admin --help`).
    *   **When to use**: For system administrators or advanced users performing database operations.
*   **`bd jira --sync [--project <project_key>] [--issue <issue_id>]`**
    *   **Purpose**: Jira integration commands for syncing issues.
    *   **How it works**: Commands to synchronize Beads issues with Jira issues. (Specific subcommands not detailed here but follow `bd jira --help`).
    *   **When to use**: To integrate Beads with Jira for issue tracking.
*   **`bd linear --sync [--issue <issue_id>]`**
    *   **Purpose**: Linear integration commands for syncing issues.
    *   **How it works**: Commands to synchronize Beads issues with Linear issues. (Specific subcommands not detailed here but follow `bd linear --help`).
    *   **When to use**: To integrate Beads with Linear for issue tracking.
*   **`bd repo <command>`**
    *   **Purpose**: Manages multi-repository configurations for Beads.
    *   **How it works**: Provides subcommands for handling settings across multiple project repositories. (Specific subcommands not detailed here but follow `bd repo --help`).
    *   **When to use**: For managing Beads across a monorepo or multiple related projects.

#### Other Commands:

*   **`bd ado <command>`**
    *   **Purpose**: Azure DevOps integration commands.
    *   **How it works**: Commands for integrating Beads with Azure DevOps. (Specific subcommands not detailed here but follow `bd ado --help`).
    *   **When to use**: To integrate Beads with Azure DevOps.
*   **`bd audit [--record <event>] [--label <label>] [--file <file_path>]`**
    *   **Purpose**: Records and labels agent interactions (append-only JSONL).
    *   **How it works**: Logs specific agent activities for auditing purposes.
    *   **When to use**: For tracking agent actions and decisions.
*   **`bd blocked`**
    *   **Purpose**: Shows issues that are currently blocked.
    *   **How it works**: Filters and displays issues whose progress is halted due to dependencies or other blockers.
    *   **When to use**: To identify immediate impediments to project progress.
*   **`bd completion <shell>`**
    *   **Purpose**: Generates the autocompletion script for a specified shell (e.g., bash, zsh, fish).
    *   **How it works**: Outputs shell commands to enable tab completion for `bd` commands.
    *   **When to use**: To improve command-line usability.
*   **`bd cook <formula> [--output <file_path>] [--ephemeral]`**
    *   **Purpose**: Compiles a workflow formula into a proto.
    *   **How it works**: Processes workflow definitions written in a specific formula language.
    *   **When to use**: For advanced workflow automation and definition.
*   **`bd defer <issue_id...>`**
    *   **Purpose**: Defers one or more issues for later consideration.
    *   **How it works**: Changes the status of issues to a "deferred" state, effectively pausing active work on them.
    *   **When to use**: To temporarily sideline issues that are not currently a priority.
*   **`bd formula <command>`**
    *   **Purpose**: Manages workflow formulas.
    *   **How it works**: Provides subcommands for defining, compiling, and managing workflow definitions. (Specific subcommands not detailed here but follow `bd formula --help`).
    *   **When to use**: For building complex, automated workflows.
*   **`bd github <command>`**
    *   **Purpose**: GitHub integration commands.
    *   **How it works**: Commands for interacting with GitHub, such as creating issues or syncing PRs. (Specific subcommands not detailed here but follow `bd github --help`).
    *   **When to use**: To integrate Beads with GitHub workflows.
*   **`bd help [command]`**
    *   **Purpose**: Displays help information about any command.
    *   **How it works**: Shows usage, flags, and descriptions for `bd` commands.
    *   **When to use**: To get immediate assistance on how to use a specific `bd` command.
*   **`bd init-safety`**
    *   **Purpose**: Explains the semantics of `bd init` flags and the destroy-token format.
    *   **How it works**: Provides detailed information on the safety and implications of initialization flags.
    *   **When to use**: To understand the safest way to initialize or re-initialize the Beads database.
*   **`bd mail [--list] [--send]`**
    *   **Purpose**: Delegates to a mail provider (e.g., `gt mail`).
    *   **How it works**: Interacts with external email services for notifications or sending reports.
    *   **When to use**: For integrating email notifications or reports into workflows.
*   **`bd mol <command>`**
    *   **Purpose**: Manages "molecule" templates (work templates).
    *   **How it works**: Provides subcommands for creating, managing, and using predefined work item templates. (Specific subcommands not detailed here but follow `bd mol --help`).
    *   **When to use**: To standardize the creation of common issue types.
*   **`bd notion --sync [--database-id <id>] [--issue <issue_id>]`**
    *   **Purpose**: Notion integration commands for syncing issues.
    *   **How it works**: Commands to synchronize Beads issues with Notion pages or databases. (Specific subcommands not detailed here but follow `bd notion --help`).
    *   **When to use**: To integrate Beads with Notion for documentation or project management.
*   **`bd orphans`**
    *   **Purpose**: Identifies orphaned issues (referenced in commits but still open).
    *   **How it works**: Scans commit history to find references to issues that are still open and might have been inadvertently left behind.
    *   **When to use**: To clean up the issue backlog and ensure all relevant work is properly tracked.
*   **`bd ready [--query <query>] [--assignee <actor>]`**
    *   **Purpose**: Shows ready work (open issues with no active blockers).
    *   **How it works**: Filters issues that are in an open state and have no unfulfilled prerequisites.
    *   **When to use**: To find tasks that can be actively worked on right now.
*   **`bd rename <issue_id> <new_id>`**
    *   **Purpose**: Renames an issue ID.
    *   **How it works**: Changes the unique identifier of an issue. Use with caution as it can break links.
    *   **When to use**: For restructuring issue identifiers, but generally discouraged once issues are linked.
*   **`bd ship <capability> [--version <version>]`**
    *   **Purpose**: Publishes a capability for cross-project dependencies.
    *   **How it works**: Makes a component or feature available as a dependency for other projects.
    *   **When to use**: For managing shared libraries or components in a multi-project environment.
*   **`bd undefer <issue_id...>`**
    *   **Purpose**: Undeferences one or more issues, restoring them to an open state.
    *   **How it works**: Reverses the effect of `bd defer`, making deferred issues active again.
    *   **When to use**: When deferred issues are now ready to be worked on.
*   **`bd version`**
    *   **Purpose**: Prints the version information for Beads.
    *   **How it works**: Displays the current version of the `bd` CLI.
    *   **When to use**: To check the installed version of Beads.

### Global Flags:

*   **`--actor <string>`**: Specifies the actor name for audit trail logging. Defaults to `$BEADS_ACTOR`, Git user.name, or `$USER`.
*   **`-C, --directory <string>`**: Changes to the specified directory before running the command. (Similar to `git -C`).
*   **`--dolt-auto-commit <policy>`**: Configures Dolt auto-commit policy. Options: `off`, `on`, `batch`. Default is `off`. Batch defers commits until `bd dolt commit` or shutdown.
*   **`--global`**: Uses the global shared-server database (`beads_global`).
*   **`-h, --help`**: Displays help information for `bd` or a specific command.
*   **`--json`**: Outputs results in JSON format.
*   **`--profile`**: Generates a CPU profile for performance analysis.
*   **`-q, --quiet`**: Suppresses non-essential output, showing only errors.
*   **`--readonly`**: Runs Beads in read-only mode, blocking all write operations. Useful for sandboxes or inspection.
*   **`--sandbox`**: Enables sandbox mode, disabling automatic synchronization.
*   **`-v, --verbose`**: Enables verbose or debug output.
*   **`-V, --version`**: Prints the current version information for Beads.

### When to Use Beads:

*   **Project Management** (Features, Tasks, Bugs): Tracking all types of work items.
*   **Dependency Management**: Visualizing and enforcing task orderings.
*   **Workflow Automation**: Implementing complex processes with gates and states.
*   **Codebase Integration**: Linking code changes directly to issues.
*   **AI Assistant Integration**: Providing a structured data source for AI agents.
*   **Personal Productivity**: Managing individual to-do lists and projects.

---

*Note: Specific subcommands for complex commands like `bd epic`, `bd swarm`, `bd vc`, `bd admin`, `bd jira`, `bd linear`, `bd repo`, `bd ado`, `bd formula`, `bd mol` are not fully detailed here but can be accessed via their respective help flags (e.g., `bd epic --help`).*

Compressed 4025 → 1603 tokens (-60%)