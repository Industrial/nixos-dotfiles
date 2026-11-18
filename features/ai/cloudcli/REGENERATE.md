# Bumping CloudCLI

`package.json` and `package-lock.json` in this directory are generated, not
hand-written. The published npm tarball ships neither, and `buildNpmPackage`
requires a lockfile, so they are produced once per version bump and committed.

## Steps

```bash
V=1.38.0                      # the new version
cd "$(mktemp -d)"
npm pack "@cloudcli-ai/cloudcli@$V"
tar xzf "cloudcli-ai-cloudcli-$V.tgz"
cd package
```

Delete `devDependencies` and `scripts` from `package.json`. This is the step that
matters: the dev tree pulls electron, electron-builder, sharp and a vite toolchain
the server never runs, and leaving it in roughly doubles the dependency closure.

```bash
npm install --package-lock-only --ignore-scripts --omit=dev
```

Then the two hashes. `prefetch-npm-deps` stages the entire closure, and this
repo's `/tmp` is a 2 GB tmpfs — without a disk-backed `TMPDIR` it dies with
`No space left on device` partway through the `darwin-x64` optional packages.

```bash
TMPDIR=/home/tom/.dotfiles/.tmp prefetch-npm-deps package-lock.json   # npmDepsHash
nix store prefetch-file "https://registry.npmjs.org/@cloudcli-ai/cloudcli/-/cloudcli-$V.tgz"
```

Copy `package.json` and `package-lock.json` here, update `version`, `hash` and
`npmDepsHash` in `package.nix`, and update the pins asserted in
`package.assay.nix` — the suite pins both hashes deliberately, so a bump that
forgets to update it fails rather than silently drifting.

## After bumping

Build it before deploying. The `postInstall` in `package.nix` hard-fails if any
of the three vendored generic-linux binaries has moved:

```
cloudcli: expected vendored <label> at <path>, not found
cloudcli: upstream layout changed; update postInstall
```

That is working as intended. Find the new path inside
`$out/lib/node_modules/@cloudcli-ai/cloudcli/node_modules` and update the
`replace_binary` call rather than dropping the guard — without the replacement
the binary runs straight into nixpkgs' stub-ld and the failure surfaces much
later, as an unexplained exit 127 when somebody opens a session.
