# Automated Flake Lock Updates

This repository includes an automated GitHub Actions workflow to keep Nix flake lock files up-to-date across all hosts.

## How It Works

The workflow performs the following actions:

1. Runs on a weekly schedule (Monday at 3:00 AM UTC)
2. Updates flake lock files for each host in the `hosts/` directory
3. Creates a separate Pull Request for each host that has updates
4. Includes detailed information about which dependencies were updated

## Setup Requirements

To enable this workflow, you need to configure a GitHub token with appropriate permissions:

1. Go to your repository settings
2. Navigate to "Settings > Secrets and variables > Actions"
3. Add a new repository secret named `PAT` (Personal Access Token)
4. Create a [personal access token](https://github.com/settings/tokens) with `repo` scope

## Manual Triggering

You can manually trigger the workflow for all hosts or a specific host:

1. Go to the "Actions" tab in your repository
2. Select the "Update Flake Locks" workflow
3. Click "Run workflow"
4. Optionally specify a host name to update only that host's flake lock

## Pull Requests

The workflow creates pull requests with the following characteristics:

- Branch name: `flake-update/{host-name}`
- Title: `chore(deps): update flake inputs for {host-name}`
- Labels: `dependencies`, `automated`
- Detailed list of updated dependencies with old and new revision hashes

## Customization

To modify the workflow schedule or behavior, edit the `.github/workflows/update-flake-locks.yml` file.

Common adjustments include:

- Changing the schedule frequency (cron expression)
- Adding or removing hosts from the matrix
- Modifying PR labels or title format 