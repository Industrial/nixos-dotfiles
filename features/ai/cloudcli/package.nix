# CloudCLI (formerly Claude Code UI) — self-hosted web UI for coding-agent sessions.
# https://github.com/siteboon/claudecodeui  ·  AGPL-3.0-or-later
#
# Built from the published npm tarball with buildNpmPackage, the same shape as
# features/ai/context7. That is a deliberate choice over the pinned-npx wrapper
# used by features/ai/paperclip: CloudCLI is a long-running service rather than a
# CLI invoked by hand, and npx in a systemd unit resolves its dependency tree over
# the network at every start — a service that silently changes what it runs when a
# transitive dependency publishes is the wrong thing to put behind a browser that
# can push to a remote. Everything here is in the closure and the build is offline.
#
# WHY THERE IS A VENDORED package.json AND package-lock.json
#
# The published tarball ships neither (upstream builds through a pnpm workspace, so
# npm never produces a v3 lock), and buildNpmPackage requires one. Both files are
# generated and committed next to this derivation. The package.json here is the
# tarball's own with devDependencies and scripts deleted — not cosmetic: that tree
# pulls electron, electron-builder, sharp and a whole vite toolchain this server
# never runs, and dropping it takes the dependency closure to 939 packages.
# Regenerate both with the commands in ./REGENERATE.md.
#
# THREE NATIVE MODULES ARE COMPILED HERE, not downloaded. bcrypt, better-sqlite3
# and node-pty are the only packages in the lock carrying install scripts, and all
# three are node-gyp builds. npm_config_build_from_source stops prebuild-install
# and node-pre-gyp reaching for a prebuilt binary first — inside the sandbox that
# attempt fails and falls through to gyp anyway, but it fails slowly and logs a
# misleading network error on the way, so skip it.
#
# ONE VENDORED BINARY IS REPLACED, AND TWO DELIBERATELY ARE NOT. This is the
# NixOS-specific reason the file is longer than context7's, and the distinction is
# worth stating because the obvious guess — "three prebuilt binaries, patch all
# three" — is wrong and costs you a working codex.
#
# Checked against the 1.37.9 lock, 2026-11-18:
#
#   @anthropic-ai/claude-agent-sdk-linux-x64/claude
#     ELF 64-bit LSB executable, dynamically linked,
#     interpreter /lib64/ld-linux-x86-64.so.2            -> REPLACED
#   @vscode/ripgrep-linux-x64/bin/rg      static-pie linked -> left alone
#   @openai/codex vendor/.../bin/codex    static-pie linked -> left alone
#
# Only the first is broken here. That interpreter path exists on NixOS but it is
# nixpkgs' stub-ld, whose entire job is to exit with "NixOS cannot run dynamically
# linked executables intended for generic linux environments" — so the child dies
# with code 127 and the caller reports something unrelated.
# features/ai/openhands documents this exact failure reaching this exact SDK
# through the ACP bridge, where it surfaces as a bare JSON-RPC -32603 "Internal
# error" with nothing else to go on.
#
# It is replaced rather than autoPatchelf'd because patchelf here is guesswork: the
# Claude CLI is a Bun single-file executable carrying its payload appended after
# the ELF image, and rewriting program headers blind on the one binary this whole
# feature depends on is not a reasonable trade. A symlink to the nixpkgs build of
# the same program is exact. It also means the UI and the terminal drive the same
# `claude` that features/ai/claude-code installs, rather than two versions of it.
#
# The other two are static-pie: no interpreter, nothing for stub-ld to refuse, and
# they run unmodified. Replacing them would be worse than redundant. codex resolves
# codex-code-mode-host, bwrap and its voice resources relative to its own location
# inside that vendor tree, so a symlink out to nixpkgs' codex breaks the siblings.
# And ripgrep is reached as `rgPath` imported from the package (see
# dist-server/.../session-conversations-search.service.js), so pinning it to a
# different ripgrep means CloudCLI's flags and its rg can drift apart.
#
# What guards the next version bump is therefore not a per-path replacement list
# but the linkage check below: it fails the build if any vendored platform binary
# needs an interpreter outside the store. That turns the whole class of problem —
# including a future release that switches ripgrep or codex to glibc — into a build
# error with a name attached, instead of an exit 127 nobody can place.
{
  lib,
  buildNpmPackage,
  fetchurl,
  makeWrapper,
  nodejs_22,
  python3,
  patchelf,
  claude-code,
  ripgrep,
}: let
  version = "1.37.9";
in
  buildNpmPackage {
    pname = "cloudcli";
    inherit version;

    src = fetchurl {
      url = "https://registry.npmjs.org/@cloudcli-ai/cloudcli/-/cloudcli-${version}.tgz";
      hash = "sha256-3ueqwG4FNdWCwAnP7ibUSr1T76ZEjH0Wgj2eqo1zVSU=";
    };

    # The npm tarball unpacks into package/.
    sourceRoot = "package";

    nodejs = nodejs_22;

    npmDepsHash = "sha256-mnVbTJJox6Lsk35veigqgQS+7fWx8ghfchGqg2NqD4Q=";

    # dist/ (client) and dist-server/ (server) arrive already compiled.
    dontNpmBuild = true;

    nativeBuildInputs = [
      makeWrapper
      python3 # node-gyp
      patchelf # vendored-binary linkage check in postInstall
    ];

    env.npm_config_build_from_source = "true";

    postPatch = ''
      cp ${./package.json} package.json
      cp ${./package-lock.json} package-lock.json
    '';

    postInstall = let
      modules = "$out/lib/node_modules/@cloudcli-ai/cloudcli/node_modules";
      claudeBinary = "${modules}/@anthropic-ai/claude-agent-sdk-linux-x64/claude";
    in ''
      # The one replacement. Guarded on the path existing: a version bump that
      # renames or drops it must fail here, not ship a package that dies at runtime.
      if [ ! -e "${claudeBinary}" ]; then
        echo "cloudcli: expected the vendored claude CLI at ${claudeBinary}" >&2
        echo "cloudcli: upstream layout changed; update postInstall in package.nix" >&2
        exit 1
      fi
      rm -f "${claudeBinary}"
      ln -s "${claude-code}/bin/claude" "${claudeBinary}"
      echo "cloudcli: vendored claude -> ${claude-code}/bin/claude"

      # And the guard that makes the next bump safe. Every other vendored platform
      # binary is expected to be static, or dynamically linked against the store.
      # Anything asking for an interpreter elsewhere is a generic-linux prebuilt
      # that will hit stub-ld, so name it now rather than at exit 127.
      #
      # Scoped to the *-linux-x64 platform packages on purpose: the three native
      # modules compiled above are legitimately dynamic, and they link into the
      # store, which is exactly what the /nix/store case below accepts.
      # One exemption, and it is a decision rather than a convenience. The check
      # found codex-resources/voice/bin/codex-voice-host asking for
      # /lib64/ld-linux-x86-64.so.2 — genuinely a generic-linux prebuilt, but one
      # CloudCLI never invokes: nothing under dist-server/ references
      # codex-voice-host or codex-resources at all, and CloudCLI's own voice feature
      # is an HTTP client (modules/voice, VOICE_API_BASE_URL). It also has no
      # nixpkgs equivalent to point at, and it carries its own bundled gstreamer.
      # So it stays unpatched and unreachable, named here so that adding a second
      # exemption is a visible edit rather than a widened glob.
      voice_host_exemption='*/codex-resources/voice/*'

      dynamic_outside_store=""
      while IFS= read -r candidate; do
        # shellcheck disable=SC2254
        case "$candidate" in
          $voice_host_exemption) continue ;;
        esac
        interpreter="$(patchelf --print-interpreter "$candidate" 2>/dev/null)" || continue
        case "$interpreter" in
          /nix/store/*) ;;
          *) dynamic_outside_store="$dynamic_outside_store$candidate ($interpreter)"$'\n' ;;
        esac
      done < <(find "${modules}" -type f -perm -u+x -path '*linux-x64*' -print)

      if [ -n "$dynamic_outside_store" ]; then
        echo "cloudcli: vendored binaries need an interpreter outside the store:" >&2
        printf '%s' "$dynamic_outside_store" >&2
        echo "cloudcli: on NixOS that interpreter is stub-ld and the process exits 127." >&2
        echo "cloudcli: replace each with its nixpkgs build in postInstall, as the" >&2
        echo "cloudcli: claude CLI above already is." >&2
        exit 1
      fi
      echo "cloudcli: vendored platform binaries are static or store-linked"

      # CLAUDE_CLI_PATH is what CloudCLI's provider layer reads to locate the agent
      # CLI; CLAUDE_CODE_EXECUTABLE is the agent SDK's own override. Both are set.
      # --set-default, not --set: a developer pointing at a local Claude build
      # should be able to override from the environment without editing this file.
      wrapProgram $out/bin/cloudcli \
        --set-default CLAUDE_CLI_PATH ${claude-code}/bin/claude \
        --set-default CLAUDE_CODE_EXECUTABLE ${claude-code}/bin/claude \
        --prefix PATH : ${lib.makeBinPath [claude-code ripgrep]}
    '';

    meta = {
      description = "Self-hosted web UI for managing Claude Code, Codex and OpenCode sessions";
      homepage = "https://github.com/siteboon/claudecodeui";
      changelog = "https://github.com/siteboon/claudecodeui/releases/tag/v${version}";
      license = lib.licenses.agpl3Plus;
      mainProgram = "cloudcli";
      platforms = ["x86_64-linux"];
    };
  }
