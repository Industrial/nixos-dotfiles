# Fish Shell Command Hashing Issue

In the fish shell, when new executables are added to your PATH (such as through direnv), the shell does not automatically recognize them until you update its internal command hash table.

## Symptoms
- The `which hermes` command shows the correct path to the hermes binary
- Running `hermes` directly results in "Unknown command: hermes" error
- This happens specifically in fish shell after `direnv allow` adds new binaries to PATH

## Solution
Run the `rehash` command in fish to update the shell's command hash table:

```fish
rehash
```

After rehashing, the `hermes` command will be found and executable.

## Alternative
You can also run the hermes binary directly by its full path (as shown by `which hermes`) until you rehash.

## Prevention
Make it a habit to run `rehash` after using `direnv allow` when working in fish shell, or add it to your fish configuration if you frequently encounter this issue.