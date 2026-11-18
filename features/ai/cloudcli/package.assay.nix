# Colocated suite for features/ai/cloudcli/package.nix.
# String-level guards (repo pattern): identity, the two pins, the vendored manifests,
# and the three prebuilt-binary replacements that make this run on NixOS at all.
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./package.nix;
  has = pat: builtins.match pat src != null;

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
    namesCloudcli = assay.eq (has ".*pname = \"cloudcli\";.*") true;
    pinsVersion = assay.eq (has ".*version = \"1\\.37\\.9\";.*") true;
    pinsTarballHash = assay.eq (has ".*hash = \"sha256-3ueqwG4FNdWCwAnP7ibUSr1T76ZEjH0Wgj2eqo1zVSU=\";.*") true;
    pinsNpmDepsHash = assay.eq (has ".*npmDepsHash = \"sha256-mnVbTJJox6Lsk35veigqgQS\\+7fWx8ghfchGqg2NqD4Q=\";.*") true;

    # The published tarball ships neither manifest, so buildNpmPackage needs both
    # copied in. Without the lockfile the build cannot resolve dependencies at all.
    # Brace-free patterns: Nix's regex engine rejects \{ as invalid.
    vendorsLockfile = assay.eq (has ".*cp .*package-lock\\.json.* package-lock\\.json.*") true;
    vendorsPackageJson = assay.eq (has ".*cp .*package\\.json.* package\\.json.*") true;
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
    usesPackageSourceRoot = assay.eq (has ".*sourceRoot = \"package\";.*") true;
    skipsBuild = assay.eq (has ".*dontNpmBuild = true;.*") true;

    # bcrypt, better-sqlite3 and node-pty are gyp builds; python3 and building from
    # source rather than reaching for a prebuilt are both load-bearing.
    hasPython3ForGyp = assay.eq (has ".*python3.*") true;
    buildsNativeFromSource = assay.eq (has ".*npm_config_build_from_source = \"true\";.*") true;

    # The vendored claude CLI is the one generic-linux prebuilt in the tree: glibc
    # dynamic, interpreter /lib64/ld-linux-x86-64.so.2, which on NixOS is stub-ld.
    # Without the replacement the child process exits 127 with nothing useful said.
    replacesClaudeBinary = assay.eq (has ".*claude-agent-sdk-linux-x64/claude.*") true;

    # ripgrep and codex are static-pie and must stay untouched: codex resolves its
    # sibling resources relative to its own path inside the vendor tree, and
    # CloudCLI imports ripgrep as rgPath rather than finding it on PATH. Replacing
    # either is the plausible-looking mistake, so pin the count: exactly one `ln -s`
    # in the whole derivation. Matching on their paths instead would false-fail,
    # because the comment block names them while explaining why they are left alone.
    exactlyOneBinaryReplacement =
      assay.eq
      (builtins.length (builtins.filter builtins.isString (builtins.split "ln -s" src)))
      2;
    documentsStaticPieFinding = assay.eq (has ".*static-pie linked -> left alone.*") true;

    # What actually guards the next bump: any vendored platform binary needing an
    # interpreter outside the store fails the build by name.
    checksVendoredLinkage = assay.eq (has ".*print-interpreter.*") true;
    rejectsNonStoreInterpreter = assay.eq (has ".*interpreter outside the store.*") true;

    # The check has exactly one exemption: codex's voice host, which is a real
    # generic-linux prebuilt but unreachable from CloudCLI. Pinning the count is the
    # point — the failure mode for a guard like this is being widened under pressure
    # on the next bump, so a second exemption has to fail this claim first.
    exactlyOneLinkageExemption =
      assay.eq
      (builtins.length (builtins.filter builtins.isString (builtins.split "_exemption=" src)))
      2;
    exemptsOnlyCodexVoice = assay.eq (has ".*codex-resources/voice.*") true;

    # A renamed or dropped vendored path must fail the build, not produce a package
    # that only breaks when somebody opens a session.
    failsLoudOnLayoutChange = assay.eq (has ".*upstream layout changed; update postInstall.*") true;

    # Both the provider layer's variable and the agent SDK's own override are set, and
    # overridable from the environment.
    setsClaudeCliPath = assay.eq (has ".*--set-default CLAUDE_CLI_PATH.*") true;
    setsClaudeCodeExecutable = assay.eq (has ".*--set-default CLAUDE_CODE_EXECUTABLE.*") true;

    exposesCloudcliAsMainProgram = assay.eq (has ".*mainProgram = \"cloudcli\";.*") true;
    isAgpl = assay.eq (has ".*license = lib\\.licenses\\.agpl3Plus;.*") true;
  }
