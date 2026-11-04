# Colocated suite: git package + config file wiring.
#
# writeTextFile is stubbed to hand back its own text, so every claim below is made against
# the gitconfig this module actually generates rather than against the source that builds
# it. A claim matched on the source would also pass on a mention in the header comment —
# and this module's header names meld and difftastic both.
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./default.nix {
    settings = {
      hostname = "h";
      username = "alice";
      userfullname = "Alice";
      useremail = "a@b.c";
      userdir = "/home/alice";
    };
    pkgs = {
      git = "git";
      writeText = name: text: name;
      writeTextFile = {text, ...}: text;
    };
  };
  gitconfig = mod.environment.etc."gitconfig".source;

  # builtins.match is POSIX ERE via libstdc++, which rejects `\[` outright — "invalid regular
  # expression", thrown past tryEval, not an escaped bracket. A literal bracket has to be
  # spelled as a one-element bracket expression: `[[]` and `[]]`. Every section header below
  # is written that way; it is not a typo. (`\\` for a literal backslash is accepted.)
  has = pattern: assay.eq (builtins.match ".*${pattern}.*" gitconfig != null) true;
  lacks = pattern: assay.eq (builtins.match ".*${pattern}.*" gitconfig != null) false;

  # A section header and one of its keys, with any number of other keys in between. [^[]
  # cannot cross into the next section, so this never matches a key from somewhere else.
  inSection = section: key: has "[[]${section}[]]([^[]*\n)* *${key}";

  # The alias body, lifted out of the generated config: everything between [alias] and the
  # next section header.
  aliasBlock = builtins.head (builtins.match ".*[[]alias[]]\n([^[]*)[[]init[]].*" gitconfig);
  aliasLines =
    builtins.filter (l: l != "")
    (builtins.filter builtins.isString (builtins.split "\n" aliasBlock));
in
  assay.suite "git" {
    packages = assay.eq mod.environment.systemPackages ["git"];

    # The stub has to be doing what the claims assume, or every `has` below is vacuous.
    configIsTheGeneratedText = inSection "user" "name = Alice";

    # delta is the pager, and the interactive filter too — without diffFilter, `git add -p`
    # falls back to git's own diff and the two renderings disagree.
    pagerIsDelta = inSection "core" "pager = delta";
    interactiveFilterIsDelta = inSection "interactive" "diffFilter = delta --color-only";
    deltaNavigates = inSection "delta" "navigate = true";
    deltaIsSideBySide = inSection "delta" "side-by-side = true";

    # difftastic as the differ, invoked by its real binary name. `cmd = difftastic ...` is
    # the mistake this claim exists to catch: git reports nothing when the tool is missing.
    diffToolIsDifftastic = inSection "diff" "tool = difftastic";
    difftoolCmdIsNotTheWrongBinary = lacks "cmd = difftastic";

    # The quotes have to survive git's config parser, so they are backslash-escaped in the
    # file. Bare quotes parse to `difft $LOCAL $REMOTE`, which word-splits on a path with a
    # space in it — a silent difftool failure, which is the family of bug this suite is for.
    difftoolCmdUsesDifft = has "cmd = difft \\\\\"[$]LOCAL\\\\\" \\\\\"[$]REMOTE\\\\\"";

    # A differ is not a merge driver: difftastic has no 3-way mode, so merge.tool must be a
    # real CLI mergetool. nvimdiff is a git built-in and nvim is already the fleet's DIFFPROG.
    mergeToolIsNvimdiff = inSection "merge" "tool = nvimdiff";
    mergeToolIsNotDifftastic = lacks "[[]merge[]]([^[]*\n)* *tool = difftastic";

    # The whole point of the change: no GTK application in a config that has to work over ssh.
    noMeldAnywhere = lacks "meld";

    # Modern defaults. zdiff3 and rerere are the two that change conflict handling; the rest
    # are quality-of-life and are asserted so a future rewrite of the block cannot drop them.
    conflictStyleIsZdiff3 = inSection "merge" "conflictStyle = zdiff3";
    rerereIsEnabled = inSection "rerere" "enabled = true";
    diffAlgorithmIsHistogram = inSection "diff" "algorithm = histogram";
    colorMovedIsOn = inSection "diff" "colorMoved = default";
    fetchPrunes = inSection "fetch" "prune = true";
    branchesSortByDate = inSection "branch" "sort = -committerdate";
    columnUiIsAuto = inSection "column" "ui = auto";

    # push.autoSetupRemote takes effect for push.default values simple, upstream and current,
    # so it composes with the pre-existing `default = current` rather than fighting it. Both
    # are claimed together because dropping either one changes what a bare `git push` does.
    pushDefaultIsCurrent = inSection "push" "default = current";
    pushAutoSetsUpstream = inSection "push" "autoSetupRemote = true";

    # Pre-existing keys that the rewrite of this block must not have displaced.
    defaultBranchIsMain = inSection "init" "defaultBranch = main";
    mergeoptionsSurvive = inSection "core" "mergeoptions = --no-edit";
    pullFastForwards = inSection "pull" "ff = true";
    pullRebases = inSection "pull" "rebase = true";
    rebaseAutoStashes = inSection "rebase" "autoStash = true";
    difftoolDoesNotPrompt = inSection "difftool" "prompt = false";

    # The alias block is the oldest thing in this file and the most easily broken by an edit
    # elsewhere in the same string literal. Hashed rather than matched, because the claim is
    # byte-for-byte identity and nothing weaker. Adding an alias is meant to fail this —
    # re-run with the printed actual value and the diff shows exactly what moved.
    aliasesAreByteIdentical =
      assay.eq (builtins.hashString "sha256" aliasBlock)
      "c398d7b7e471b6e8c4c03729b559f4c81e95ce90d291c2086ee41d9d853d9f73";
    aliasCount = assay.eq (builtins.length aliasLines) 42;
  }
