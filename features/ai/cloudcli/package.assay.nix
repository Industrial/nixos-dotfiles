# Colocated suite for features/ai/cloudcli/package.nix.
# Asserts on the evaluated derivation: identity, the two pins, the vendored manifests,
# and the prebuilt-binary handling that makes this run on NixOS at all. postPatch and
# postInstall are matched as text because they ARE text: the generated build steps.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  # Substring test over generated text; store-path context is irrelevant to the match.
  contains = needle: s: lib.hasInfix (builtins.unsafeDiscardStringContext needle) (builtins.unsafeDiscardStringContext s);
  inherit (nixos.evalSystem {modules = [];}) pkgs;
  drv = pkgs.callPackage ./package.nix {};
  install = drv.postInstall;
  # Shell comments in postInstall explain the choices; the counting claims read commands.
  installCode =
    lib.concatStringsSep "\n"
    (builtins.filter (l: builtins.match "[[:space:]]*#.*" l == null) (lib.splitString "\n" install));
  occurrences = needle: s: builtins.length (builtins.filter builtins.isString (builtins.split needle s)) - 1;

  # The lockfile is parsed, not pattern-matched. builtins.match with a leading `.*`
  # over 488 KB overflows Nix's regex stack ("stack overflow (possible infinite
  # recursion)"), and attribute lookups answer these questions exactly anyway.
  lock = builtins.fromJSON (builtins.readFile ./package-lock.json);
  lockPackages = lock.packages;
  lockRoot = builtins.getAttr "" lockPackages;
  lockHasModule = name: builtins.hasAttr "node_modules/${name}" lockPackages;
  manifest = builtins.fromJSON (builtins.readFile ./package.json);
in
  assay.suite "cloudcli-package" {
    namesCloudcli = assay.eq drv.pname "cloudcli";
    pinsVersion = assay.eq drv.version "1.37.9";
    tarballMatchesVersion = assay.eq drv.src.url "https://registry.npmjs.org/@cloudcli-ai/cloudcli/-/cloudcli-${drv.version}.tgz";
    pinsTarballHash = assay.eq drv.src.outputHash "sha256-3ueqwG4FNdWCwAnP7ibUSr1T76ZEjH0Wgj2eqo1zVSU=";
    pinsNpmDepsHash = assay.eq drv.npmDeps.outputHash "sha256-mnVbTJJox6Lsk35veigqgQS+7fWx8ghfchGqg2NqD4Q=";

    # The published tarball ships neither manifest, so buildNpmPackage needs both
    # copied in. Without the lockfile the build cannot resolve dependencies at all.
    vendorsLockfile = assay.eq (builtins.match ".*cp /nix/store/[^ ]*-package-lock\\.json package-lock\\.json\n.*" drv.postPatch != null) true;
    vendorsPackageJson = assay.eq (builtins.match ".*cp /nix/store/[^ ]*-package\\.json package\\.json\n.*" drv.postPatch != null) true;
    lockfileExists = assay.eq (builtins.pathExists ./package-lock.json) true;
    packageJsonExists = assay.eq (builtins.pathExists ./package.json) true;

    # The dev tree (electron, electron-builder, sharp, vite) is stripped from the
    # manifest before the lock is generated. If it leaks back in, the closure
    # roughly doubles for a set of tools this server never runs.
    manifestHasNoDevDeps = assay.eq (builtins.hasAttr "devDependencies" manifest) false;
    lockRootHasNoDevDeps = assay.eq (builtins.hasAttr "devDependencies" lockRoot) false;
    lockHasNoElectron = assay.eq (lockHasModule "electron") false;
    lockHasNoVite = assay.eq (lockHasModule "vite") false;
    lockHasNoSharp = assay.eq (lockHasModule "sharp") false;
    lockHasNoDevEntries = assay.eq (builtins.any (p: p.dev or false) (builtins.attrValues lockPackages)) false;

    # The pairing that actually broke the first build: a manifest carrying
    # devDependencies against a lock generated without them makes npm reach for
    # @commitlint/cli at install time and fail ENOTCACHED inside the sandbox. Assert
    # the two agree rather than trusting that they were generated together.
    manifestAndLockAgreeOnDeps =
      assay.eq
      (builtins.attrNames manifest.dependencies)
      (builtins.attrNames lockRoot.dependencies);
    manifestAndLockAgreeOnVersion = assay.eq manifest.version lock.version;

    # Every native module that needs compiling, named. If a bump adds a fourth, the
    # build may still succeed by silently downloading a prebuilt — this is what
    # notices.
    lockInstallScriptsAreTheKnownThree =
      assay.eq
      (builtins.filter (n: (builtins.getAttr n lockPackages).hasInstallScript or false)
        (builtins.attrNames lockPackages))
      [
        "node_modules/bcrypt"
        "node_modules/better-sqlite3"
        "node_modules/node-pty"
      ];

    # The tarball unpacks into package/ and already ships compiled dist/ + dist-server/.
    usesPackageSourceRoot = assay.eq drv.sourceRoot "package";
    skipsBuild = assay.eq drv.dontNpmBuild true;
    buildsOnNode22 = assay.eq drv.nodejs.outPath pkgs.nodejs_22.outPath;

    # bcrypt, better-sqlite3 and node-pty are gyp builds; python3 and building from
    # source rather than reaching for a prebuilt are both load-bearing.
    hasPython3ForGyp = assay.eq (builtins.elem pkgs.python3.outPath (map (p: p.outPath) drv.nativeBuildInputs)) true;
    buildsNativeFromSource = assay.eq drv.drvAttrs.npm_config_build_from_source "true";

    # The vendored claude CLI is the one generic-linux prebuilt in the tree: glibc
    # dynamic, interpreter /lib64/ld-linux-x86-64.so.2, which on NixOS is stub-ld.
    # Without the replacement the child process exits 127 with nothing useful said.
    replacesClaudeBinary =
      assay.eq
      (contains "ln -s \"${pkgs.claude-code}/bin/claude\" \"$out/lib/node_modules/@cloudcli-ai/cloudcli/node_modules/@anthropic-ai/claude-agent-sdk-linux-x64/claude\"" install)
      true;

    # ripgrep and codex are static-pie and must stay untouched: codex resolves its
    # sibling resources relative to its own path inside the vendor tree, and
    # CloudCLI imports ripgrep as rgPath rather than finding it on PATH. Replacing
    # either is the plausible-looking mistake, so pin the count: exactly one `ln -s`
    # among postInstall's commands.
    exactlyOneBinaryReplacement = assay.eq (occurrences "ln -s" installCode) 1;

    # What actually guards the next bump: any vendored platform binary needing an
    # interpreter outside the store fails the build by name.
    checksVendoredLinkage = assay.eq (contains "patchelf --print-interpreter" installCode) true;
    rejectsNonStoreInterpreter = assay.eq (contains "need an interpreter outside the store" installCode) true;
    hasPatchelfForLinkageCheck = assay.eq (builtins.elem "patchelf" (map lib.getName drv.nativeBuildInputs)) true;

    # The check has exactly one exemption: codex's voice host, which is a real
    # generic-linux prebuilt but unreachable from CloudCLI. Pinning the count is the
    # point — the failure mode for a guard like this is being widened under pressure
    # on the next bump, so a second exemption has to fail this claim first.
    exactlyOneLinkageExemption = assay.eq (occurrences "_exemption=" installCode) 1;
    exemptsOnlyCodexVoice = assay.eq (contains "voice_host_exemption='*/codex-resources/voice/*'" installCode) true;

    # A renamed or dropped vendored path must fail the build, not produce a package
    # that only breaks when somebody opens a session.
    failsLoudOnLayoutChange = assay.eq (contains "upstream layout changed; update postInstall" installCode) true;

    # Both the provider layer's variable and the agent SDK's own override are set, and
    # overridable from the environment.
    setsClaudeCliPath = assay.eq (contains "--set-default CLAUDE_CLI_PATH ${pkgs.claude-code}/bin/claude" installCode) true;
    setsClaudeCodeExecutable = assay.eq (contains "--set-default CLAUDE_CODE_EXECUTABLE ${pkgs.claude-code}/bin/claude" installCode) true;

    exposesCloudcliAsMainProgram = assay.eq drv.meta.mainProgram "cloudcli";
    isAgpl = assay.eq drv.meta.license.spdxId "AGPL-3.0-or-later";
  }
