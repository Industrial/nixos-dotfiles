# Lutris/Steam Environment Inheritance Troubleshooting

## Symptom
After launching Lutris from a terminal (in the foreground), attempting to start Steam from the desktop menu (or another terminal that inherits the same environment) results in Steam not launching (no window, no error).

## Cause
Lutris, when run in the foreground from a terminal, may set environment variables (e.g., `LD_LIBRARY_PATH`, `SDL_VIDEODRIVER`) that are inherited by child processes. If the desktop menu or another terminal is started from the same session, it can inherit these variables, causing Steam to fail silently.

## Diagnosis
1. Check if launching Steam from a fresh terminal (e.g., via `Alt+F2` or a new terminal tab) works.
2. If it works, the issue is environment inheritance from the Lutris process.
3. Examine the environment in the terminal where Lutris was run:
   ```bash
   env | grep -E 'LD_LIBRARY_PATH|SDL_VIDEODRIVER'
   ```
4. Compare with the environment in a fresh terminal.

## Solution
- Run Lutris in the background or from the desktop menu to avoid blocking the terminal and preventing environment pollution:
  ```bash
  lutris &
  ```
  or quit Lutris and start it from the application menu.
- After starting Lutris via the menu, try launching Steam from the menu again.
- If the problem persists, launch Steam from a terminal to see any error output:
  ```bash
  steam
  ```

## Prevention
- Always run GUI applications that may modify the environment in the background or via the desktop menu.
- Be cautious when running terminal commands that set environment variables; they can affect subsequently launched GUI applications if they share the same session.

## NixOS Specifics
On NixOS, Lutris and Steam are typically installed via Nix and managed in the user's environment. The issue is not specific to NixOS but to the way environment variables are inherited in Linux desktop sessions.