#!/usr/bin/env bash
# Runs idAutomation's Upkeep test suite against idUpkeep. Needs ../idAutomation (its
# WoW stubs) and busted (idAutomation's devenv profile has it).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
ida="$here/../../idAutomation"
cd "$ida"
PATH="$ida/.devenv/profile/bin:$PATH" busted --lpath='./?.lua;./?/init.lua' --helper="$here/helper.lua" -p '%.test%.lua' "$here"
