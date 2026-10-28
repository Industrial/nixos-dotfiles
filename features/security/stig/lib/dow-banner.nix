# The Standard Mandatory DoW Notice and Consent Banner, verbatim.
#
# Three controls require this text in three different places — V-268082 (console/CLI),
# V-268083 (SSH) and V-268084 (graphical greeter) — and their fix texts each repeat the whole
# thing. Repeating a long legal string three times is how one copy silently drifts from the
# others, so it lives here once and the three controls cite it.
#
# Transcribed from V-268082's fix text in the vendored V1R3 XCCDF. Two forms, because the
# consumers differ: `multiline` for options that render a block (getty.helpLine,
# openssh.banner) and `singleLine` for the graphical greeter, whose option takes one string
# with escaped newlines.
#
# ⚠ Do not reword this. It is a legal notice whose exact text is the requirement, and V1R3
# already renamed "Department of Defense" to "Department of War" once — data/PROVENANCE.md
# records that any implementation carrying the older wording fails all three controls
# silently.
rec {
  paragraphs = [
    "You are accessing a U.S. Government (USG) Information System (IS) that is provided for USG-authorized use only."
    "By using this IS (which includes any device attached to this IS), you consent to the following conditions:"
    "-The USG routinely intercepts and monitors communications on this IS for purposes including, but not limited to, penetration testing, COMSEC monitoring, network operations and defense, personnel misconduct (PM), law enforcement (LE), and counterintelligence (CI) investigations."
    "-At any time, the USG may inspect and seize data stored on this IS."
    "-Communications using, or data stored on, this IS are not private, are subject to routine monitoring, interception, and search, and may be disclosed or used for any USG-authorized purpose."
    "-This IS includes security measures (e.g., authentication and access controls) to protect USG interests--not for your personal benefit or privacy."
    "-Notwithstanding the above, using this IS does not constitute consent to PM, LE or CI investigative searching or monitoring of the content of privileged communications, or work product, related to personal representation or services by attorneys, psychotherapists, or clergy, and their assistants. Such communications and work product are private and confidential. See User Agreement for details."
  ];

  # Blank line between paragraphs, as the fix text renders it.
  multiline = builtins.concatStringsSep "\n\n" paragraphs + "\n";

  # One line with literal \n separators, for options that take a single string.
  singleLine = builtins.concatStringsSep "\n" paragraphs;
}
