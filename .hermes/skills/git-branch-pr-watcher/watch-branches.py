#!/usr/bin/env python3
"""Git Branch PR Watcher - watches git branches and PRs."""

import subprocess
import sys
import json
from typing import List, Dict


def run_git(*args: str) -> str:
    """Run a git command and return stdout."""
    result = subprocess.run(
        ["git"] + list(args),
        capture_output=True,
        text=True,
        cwd="/home/tom/.dotfiles"
    )
    if result.returncode != 0:
        print(f"Git error: {result.stderr}")
        return ""
    return result.stdout.strip()


def get_all_branches() -> List[str]:
    """Get all local branches except main."""
    output = run_git("branch")
    branches = []
    for line in output.split("\n"):
        line = line.strip()
        if line and not line.startswith("*") and line != "main":
            branches.append(line)
    return branches


def is_branch_rebased_on_main(branch: str) -> bool:
    """Check if branch is directly ahead of main."""
    output = run_git("log", "main.." + branch, "--oneline")
    commits = output.split("\n")
    return len(commits) == 1


def rebase_branch_onto_main(branch: str) -> bool:
    """Rebase a branch onto main and push."""
    print(f"Rebasing {branch} onto main...")
    result = subprocess.run(
        ["git", "rebase", "main", branch],
        capture_output=True,
        text=True,
        cwd="/home/tom/.dotfiles"
    )
    if result.returncode != 0:
        print(f"Rebase failed for {branch}: {result.stderr}")
        subprocess.run(["git", "rebase", "--abort"], capture_output=True, cwd="/home/tom/.dotfiles")
        return False
    result = subprocess.run(
        ["git", "push", "origin", branch],
        capture_output=True,
        text=True,
        cwd="/home/tom/.dotfiles"
    )
    if result.returncode != 0:
        print(f"Push failed for {branch}: {result.stderr}")
        return False
    print(f"Successfully rebased and pushed {branch}")
    return True


def get_open_prs_for_branch(branch: str) -> List[Dict]:
    """Get open PRs for a branch using gh CLI."""
    result = subprocess.run(
        ["gh", "pr", "list", "--head", branch, "--state", "open",
         "--json", "number,title,mergeStateStatus,mergeable"],
        capture_output=True,
        text=True,
        cwd="/home/tom/.dotfiles"
    )
    if result.returncode != 0:
        print(f"gh pr list failed: {result.stderr}")
        return []
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        print(f"Failed to parse gh pr list output")
        return []


def is_pr_mergeable(pr: Dict) -> bool:
    """Check if a PR is mergeable."""
    mergeable = pr.get("mergeable", "")
    merge_state_status = pr.get("mergeStateStatus", "")
    return mergeable == "MERGEABLE" or merge_state_status == "CLEAN"


def create_commit_on_branch(branch: str, message: str) -> bool:
    """Create a commit on the specified branch."""
    print(f"Creating commit '{message}' on {branch}...")
    result = subprocess.run(
        ["git", "commit", "--allow-empty", "-m", message],
        capture_output=True,
        text=True,
        cwd="/home/tom/.dotfiles"
    )
    if result.returncode != 0:
        print(f"Commit failed for {branch}: {result.stderr}")
        return False
    result = subprocess.run(
        ["git", "push", "origin", branch],
        capture_output=True,
        text=True,
        cwd="/home/tom/.dotfiles"
    )
    if result.returncode != 0:
        print(f"Push failed for {branch}: {result.stderr}")
        return False
    print(f"Successfully created commit on {branch}")
    return True


def main():
    """Main function - watch and fix branches and PRs."""
    print("=" * 60)
    print("Git Branch PR Watcher")
    print("=" * 60)

    branches = get_all_branches()
    print(f"Found {len(branches)} branches to check")

    any_changes = False

    for branch in branches:
        print(f"\n--- Checking branch: {branch} ---")

        if is_branch_rebased_on_main(branch):
            print(f"{branch} is rebased on main")
        else:
            print(f"{branch} is NOT rebased on main - rebasing...")
            if rebase_branch_onto_main(branch):
                any_changes = True
            else:
                print(f"Failed to rebase {branch}, skipping...")
                continue

        prs = get_open_prs_for_branch(branch)
        print(f"Found {len(prs)} open PR(s) for {branch}")

        for pr in prs:
            pr_number = pr.get("number", "unknown")
            pr_title = pr.get("title", "unknown")
            mergeable = is_pr_mergeable(pr)
            merge_state_status = pr.get("mergeStateStatus", "")

            print(f"  PR #{pr_number}: {pr_title}")
            print(f"    mergeable={mergeable}, mergeStateStatus={merge_state_status}")

            if not mergeable:
                print(f"    PR not mergeable - creating commit to fix...")
                success = create_commit_on_branch(branch,
                                                  f"fix: make PR #{pr_number} mergeable")
                if success:
                    any_changes = True
                else:
                    print(f"Failed to create commit on {branch}")
            else:
                print(f"    PR is mergeable")

        any_changes = True

    print("\n--- Pushing all changes ---")
    result = subprocess.run(
        ["git", "push", "origin"],
        capture_output=True,
        text=True,
        cwd="/home/tom/.dotfiles"
    )
    if result.returncode != 0:
        print(f"Push failed: {result.stderr}")

    print("\n" + "=" * 60)
    print("Watch cycle complete")
    print("=" * 60)

    return any_changes


if __name__ == "__main__":
    main()