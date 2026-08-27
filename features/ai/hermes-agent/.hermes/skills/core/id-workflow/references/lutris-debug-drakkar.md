# Lutris Debug Session on Drakkar (2026-08-25)

## Symptom
Starting Steam via Lutris on NixOS host Drakkar results in no visible UI. Running `lutris` in terminal shows:

```
AttributeError: module 'gi._gi' has no attribute 'OptionContext'
```

## Environment
- Host: drakkar (x86_64-linux)
- Lutris version: 0.5.22 (Nix package)
- Python version: 3.14.7 (system)
- PyGObject version: 3.54.5 (from error trace)
- Lutris wrapper: /nix/store/9jc3v605932gbc2b8rvds6k5f70dm39l-lutris-unwrapped-0.5.22

## Diagnosis
The error indicates a mismatch between the PyGObject version Lutris expects and the one provided. Lutris 0.5.22 may require a newer PyGObject that provides `OptionContext` in the gi overrides.

Steps taken:
1. Verified Lutris package path: `/run/current-system/sw/bin/lutris`
2. Checked requisites: Lutris depends on python3.14.7 and pygobject 3.54.5
3. Considered version skew: Lutris might have been built against a different PyGObject version.

## Potential Fixes
- Update Lutris to a newer version if available in Nixpkgs.
- Rebuild Lutris against the current PyGObject.
- Use `nix shell` to test with a different Lutris version.
- Check if Lutris needs to be configured to use a specific Python interpreter.

## Resolution (not applied in this session)
No fix was applied as the session remained in ORIENT/RESEARCH mode per ID workflow. Further investigation would require:
- Checking NixOS configuration for Lutris overrides.
- Testing with `nix run nixpkgs#lutris` to see if the issue persists.
- Possibly reporting the issue to Nixpkgs Lutris maintainers.