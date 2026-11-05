# `cheatsheet` was `curl "https://cheat.sh/$@"` and nothing else: no offline answer, no
# knowledge of this fleet, and a network round trip for `cheatsheet tar`. (It also declared
# `buildInputs = [pkgs.dust]`, copy-pasted from features/cli/du, which the script never used.)
#
# It is now a router over the two things that do know the answer. The local tldr page cache
# first — features/cli/tealdeer seeds it from a pinned archive and refreshes it on a timer, so
# it answers with no network at all — and cheat.sh only when asked for by name with `--web`.
# This repo's own commands are not here: they are .cheat files in features/cli/navi, which the
# miss message names.
#
# WHY THIS STILL EXISTS. profiles/cli-core.nix imports this directory, and a dangling import
# breaks every host. Deleting the feature is the better end state and needs that one import
# line removed in the same commit — see README.md beside this file. Reducing it in place is
# what one leaf can do without reaching into profiles/.
{pkgs, ...}: let
  cheatsheet = pkgs.writeShellApplication {
    name = "cheatsheet";
    runtimeInputs = [pkgs.tealdeer pkgs.curl];
    text = ''
      usage() {
        printf '%s\n' \
          'Usage: cheatsheet <command>' \
          '       cheatsheet --web <topic>...' \
          "" \
          '  (default)  the local tldr page for <command>, out of the offline cache' \
          '  --web      ask cheat.sh instead; the only path here that needs the network' \
          "" \
          "This fleet's own commands are in navi, not here:  navi --tag-rules dotfiles"
      }

      case "''${1-}" in
        -h | --help)
          usage
          exit 0
          ;;
        "")
          usage >&2
          exit 1
          ;;
        --web)
          shift
          if [ "$#" -eq 0 ]; then
            usage >&2
            exit 1
          fi
          # cheat.sh takes its topic as a path: cheat.sh/python/lambda. The old one-liner
          # interpolated "$@" straight into the URL, which produced a broken request for
          # anything but a single word.
          exec curl --fail --silent --show-error \
            "https://cheat.sh/$(printf '%s' "$*" | tr ' ' '/')"
          ;;
      esac

      if ! tldr "$@"; then
        echo "cheatsheet: no local tldr page for '$*'." >&2
        echo "  this fleet's own commands:  navi --query '$*'" >&2
        echo "  the internet's answer:      cheatsheet --web $*" >&2
        exit 1
      fi
    '';
  };
in {
  environment.systemPackages = [
    cheatsheet
  ];
}
