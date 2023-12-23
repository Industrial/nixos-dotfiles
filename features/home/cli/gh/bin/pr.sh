#!/usr/bin/env bash

# Get the current branch name.
BRANCH_NAME=$(git symbolic-ref --short HEAD)
echo "pr > Current branch is ${BRANCH_NAME}."

# Check if there are any changes in the staging area.
git diff --cached --quiet
if [[ $? -ne 0 ]]; then
  echo "pr > There are changes in the staging area. Please commit or stash them."
  exit 1
fi

# Fetch the latest changes from the remote.
echo "pr > Fetching the latest changes from the remote."
git fetch origin

# Check if the branch has been pushed to the remote. If not, push it.
echo "pr > Checking if the branch has been pushed to the remote."
if [[ $(git branch -r --list origin/${BRANCH_NAME}) == "" ]]; then
  echo "pr > Pushing the branch to the remote."
  git push --set-upstream origin ${BRANCH_NAME}
else
  echo "pr > The branch has already been pushed to the remote."
fi

# Use the GitHub CLI to check if a PR already exists for the branch.
echo "pr > Checking if a PR already exists for branch ${BRANCH_NAME}."
if [[ $(gh pr list --state open --base main --head ${BRANCH_NAME} | wc -l) -ne 0 ]]; then
  echo "A PR already exists for branch ${BRANCH_NAME}."
  exit 1
else
  echo "Creating a PR for branch ${BRANCH_NAME}."
  gh pr create --title "${BRANCH_NAME}"
fi

# Set the PR to auto-merge and delete the branch when merged.
echo "pr > Setting the PR to auto-merge and delete the branch when merged."
gh pr merge --auto --delete-branch --squash "${BRANCH_NAME}"
