# V-268119 (CAT II) — NixOS audit system must protect logon UIDs from unauthorized change.
#
# Fix text: a single `--loginuid-immutable` rule. Once loaded, a process's loginuid cannot be
# changed even by root, which is what makes audit attribution trustworthy.
{...}: {
  security.audit.rules = [
    "--loginuid-immutable"
  ];
}
