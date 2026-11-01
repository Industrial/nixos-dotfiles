# Colocated suite for hosts/huginn/disko.nix.
#
# Beyond the repo's usual non-empty smoke check, this asserts full-disk encryption. That is
# Anduril NixOS STIG V-268144 ("must protect the confidentiality and integrity of all
# information at rest", CAT I) — the one CAT I control whose answer lives in the disko layout
# rather than in a NixOS option, so this is where it can be proven.
let
  assay = import ./../../common/assay/default.nix;
  src = builtins.readFile ./disko.nix;
  has = pat: builtins.match pat src != null;

  # Some assertions below count how many times an option value is written, which only means
  # anything if prose in the comments is not counted too. Strip comment-only lines first.
  lines = builtins.filter builtins.isString (builtins.split "\n" src);
  code = builtins.concatStringsSep "\n" (
    builtins.filter (l: builtins.match "[[:space:]]*#.*" l == null) lines
  );
  # builtins.split returns 2n+1 elements for n matches.
  occurrences = pat: (builtins.length (builtins.split pat code) - 1) / 2;
in
  assay.suite "huginn-disko" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 20) true;

    # V-268144: the root filesystem sits inside a LUKS container.
    encryptsAtRest = assay.eq (has ".*type = \"luks\";.*") true;
    namesCryptroot = assay.eq (has ".*name = \"cryptroot\";.*") true;
    # No keyfile baked into the store — the passphrase is entered at boot.
    noKeyFileInStore = assay.eq (has ".*keyFile = null;.*") true;

    # The ESP cannot be encrypted, so its permissions carry the weight instead: umask 0077
    # keeps /boot unreadable to non-root.
    bootIsOwnerOnly = assay.eq (has ".*umask=0077.*") true;

    btrfsRootInsideLuks = assay.eq (has ".*type = \"btrfs\";.*") true;
    separatesNixAndHomeSubvolumes =
      assay.eq (has ".*\"@nix\".*" && has ".*\"@home\".*") true;

    # Tablet-specific departures from the fleet layout. Each one is a deliberate choice that a
    # future copy-paste from another host would silently undo, so each gets an assertion.

    # Transparent compression and no atime writes on the data subvolumes.
    compressesData = assay.eq (has ".*\"compress=zstd\".*") true;
    noAtimeWrites = assay.eq (has ".*\"noatime\".*") true;

    # Hibernation swap: a dedicated subvolume holding a swapfile, large enough for the 16G of
    # RAM the StarLite 5 ships with.
    hasSwapSubvolume = assay.eq (has ".*\"@swap\".*") true;
    swapfileFitsRam = assay.eq (has ".*swap.swapfile.size = \"20G\";.*") true;

    # The @swap subvolume must stay uncompressed, so that a working swapfile never depends on
    # mkswapfile's per-file NODATACOW flag surviving a future edit. Assert the shape that makes
    # it true: `compress=zstd` is written exactly once, in the shared dataOptions binding, so
    # no subvolume can pick it up without referencing that binding; and `noatime` is written
    # twice, which is dataOptions plus @swap's own separate list.
    compressionDefinedOnce = assay.eq (occurrences "compress=zstd") 1;
    compressionLivesInDataOptions =
      assay.eq (has ".*dataOptions = .*compress=zstd.*") true;
    swapHasItsOwnMountOptions = assay.eq (occurrences "noatime") 2;

    # The btrfs filesystem must have no top-level mountpoint. With one, disko mounts subvolid 5
    # at the mount root during install — it wins the attrset collision against the @root
    # subvolume mount — so nixos-install writes `/` into the bare volume while the installed
    # system boots with subvol=@root. Mounting only via subvolumes keeps the two in agreement.
    rootMountedViaSubvolumeOnly =
      assay.eq (has ".*type = \"btrfs\";[[:space:]]*mountpoint = \"/\";.*") false;
  }
