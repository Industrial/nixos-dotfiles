Coverage threshold for andromeda project is set to 95% in notebooks/andromeda/moon.yml and must never be changed by AI.
§
User prefers class-level skill organization, concise direct responses with verification of changes, and concrete implemented solutions connected to codebase patterns rather than abstract designs.
§
When working with NixOS features in this repo, check if they need to be added to profiles/base.nix to be active on all hosts. Secure Boot module was created but not active until added to base profile.
§
Persistent service state lives in /data/services/<name> (NFS-exported). Mimir's rootless containers own ports 5432/5433 - NixOS postgresql stays on 5434. features/media/homarr now runs as an OCI container (ghcr.io/homarr-labs/homarr) and works; never reintroduce the old npm-start variant.
§
User prefers concise, direct responses, verification of changes, NixOS configuration work without Home Manager, class-level skill organization, and using 'hermes config set' for individual configuration changes due to security restrictions.
§
Prometheus on mimir (:9001) scrapes node_exporters fleet-wide via <host>:9002 targets in its nodes job.
§
.hermes directories (repo-root and features/ai/hermes-agent/.hermes) are off limits — never create, modify, or test there; hermes plugin templates stay exempt from assay suites by user directive 2026-08-23.
§
Dotfiles repo: meta git hooks named 'pre-commit'/'pre-push' invoke those literal binary names which don't exist outside devenv; commits/pushes fail with ENOENT after real gates pass — use SKIP=pre-commit for commits and SKIP=pre-push for pushes (moon-test/assay and deepsec still run).
§
Assay authoring: builtins.match is POSIX ERE (write [ as [[]); `or` is a keyword, use ?-defaults; subset claim is positional on lists (set-containment only for attrsets); colocated suites import modules with stub pkgs/lib/writers args.