# Colocated suite: the DoW consent banner text is intact and correctly worded.
#
# This is a legal notice whose exact text IS the requirement, shared by three controls. The
# cases below are the ones that would catch a silent rewording — including the DoD→DoW rename
# that V1R3 made, which an implementation carrying the old text fails without any error.
let
  assay = import ./../../../../common/assay/default.nix;
  banner = import ./dow-banner.nix;
  stig = import ./parse-xccdf.nix;
in
  assay.suite "stig-dow-banner" {
    sevenParagraphs = assay.eq (builtins.length banner.paragraphs) 7;

    opensWithTheRequiredSentence =
      assay.eq (builtins.head banner.paragraphs)
      "You are accessing a U.S. Government (USG) Information System (IS) that is provided for USG-authorized use only.";

    # Every paragraph of our text must appear verbatim in the benchmark's own fix text. This
    # is the assertion that makes "transcribed from the XCCDF" checkable rather than claimed.
    everyParagraphIsInTheBenchmark = let
      fix = (stig.get "V-268082").fixtext;
      contains = p: builtins.match ".*${builtins.replaceStrings ["(" ")" "[" "]" "." "*" "+" "?" "\\"] ["\\(" "\\)" "\\[" "\\]" "\\." "\\*" "\\+" "\\?" "\\\\"] p}.*" fix != null;
    in
      assay.eq (builtins.filter (p: !contains p) banner.paragraphs) [];

    # V1R3 wording. "Department of Defense" anywhere would mean the pre-V1R3 text.
    hasNoPreV1R3Wording = assay.eq (builtins.match ".*Department of Defense.*" banner.multiline) null;

    # Both renderings carry the same content; only the separators differ.
    multilineSeparatesParagraphs = assay.eq (builtins.length (builtins.filter builtins.isString (builtins.split "\n\n" banner.multiline))) 7;
    singleLineIsOneBlock = assay.eq (builtins.match ".*\n\n.*" banner.singleLine) null;
    bothMentionConsent = assay.eq (builtins.match ".*you consent to the following conditions.*" banner.singleLine != null) true;

    # The attorney/psychotherapist/clergy carve-out is the paragraph most likely to be
    # trimmed as boilerplate, and it is the one with legal weight.
    retainsPrivilegedCommunicationsCarveOut =
      assay.eq (builtins.match ".*attorneys, psychotherapists, or clergy.*" banner.multiline != null) true;
  }
