# The two copies that move a host's stateful /etc across the setup-etc.pl <-> overlay
# boundary (GH-185). Not a module: features/nixos/etc-overlay/default.nix (entry, live and
# cold) and ./exit.nix (leaving, live and at boot) call these scripts.
#
# "Stateful" means a file some program wrote, not one the generation declares:
#   - in, from a setup-etc.pl /etc: every regular file or symlink that is not a symlink
#     into /etc/static, not one of setup-etc.pl's copies (listed in /etc/.clean), and not
#     declared by the generation being entered (present in its /etc tree);
#   - out, from the overlay: every entry of the upperdir (runtime writes only, by
#     construction) that the generation being entered does not declare. A whiteout there
#     (a 0:0 character device: a file deleted while the overlay was mounted) deletes it,
#     and so does a file carried in (listed in the carried-in list) that is no longer in
#     the upperdir: deleting an upper-only file leaves no whiteout behind.
#
# Every copy keeps mode, owner, timestamps and xattrs (cp -a), and creates missing parent
# directories with the source's attributes (--parents). A failed copy is reported and
# skipped; neither script fails the activation or the boot it runs in.
#
# Shell, not Voltaic: both run before /etc exists in its final form, one of them in the
# initrd next to upstream's own shell (nixos/modules/system/etc/etc.nix), and they are
# glue around coreutils' cp. A candidate for the vetc crate if one is ever built.
{
  pkgs,
  lib,
}: let
  tools = [pkgs.coreutils pkgs.findutils pkgs.gnugrep];
  path = lib.makeBinPath tools;
in {
  # What the initrd needs besides the scripts: its store paths are copied with their
  # binaries' libraries, but a script's references are not followed.
  inherit tools;

  # carryIn <setup-etc.pl /etc> <overlay upperdir> <the entered generation's /etc tree> <carried-in list>
  # Copies only what the upperdir does not have yet; appends each copied path, NUL-ended,
  # to the list.
  carryIn = pkgs.writeShellScript "etc-overlay-carry-in" ''
    set -u
    export PATH=${path}
    src=$1 upper=$2 lower=$3 list=$4
    touch "$list"
    cd "$src" || exit 0
    n=0
    while IFS= read -r -d "" p; do
      # .clean and static are setup-etc.pl's own: its list of copies, and its link to
      # the generation's /etc tree (in the upperdir it would hide the new one).
      case "$p" in .clean | static | .rw-etc*) continue ;; esac
      if [ -L "$p" ]; then
        case "$(readlink "$p")" in /etc/static/*) continue ;; esac
      fi
      if [ -f .clean ] && grep -qxF -- "$p" .clean; then continue; fi
      if [ -e "$lower/$p" ] || [ -L "$lower/$p" ]; then continue; fi
      if [ -e "$upper/$p" ] || [ -L "$upper/$p" ]; then continue; fi
      if cp -a --parents -- "$p" "$upper/"; then
        n=$((n + 1))
        printf '%s\0' "$p" >> "$list"
        echo "etc-overlay: carried in /etc/$p"
      else
        echo "etc-overlay: FAILED to carry in /etc/$p" >&2
      fi
    done < <(find . -xdev -mindepth 1 \( -type f -o -type l \) -printf '%P\0')
    echo "etc-overlay: carried $n file(s) from $src into $upper"
  '';

  # carryOut <overlay upperdir> <where to read each file> <setup-etc.pl /etc> <the entered generation's /etc tree> <carried-in list>
  # Overwrites: what the overlay holds is newer than what the old /etc kept.
  carryOut = pkgs.writeShellScript "etc-overlay-carry-out" ''
    set -u
    export PATH=${path}
    upper=$1 content=$2 dst=$3 lower=$4 list=$5
    cd "$upper" || exit 0
    n=0
    if [ -f "$list" ]; then
      while IFS= read -r -d "" p; do
        if [ ! -e "$p" ] && [ ! -L "$p" ] && [ ! -e "$lower/$p" ] && [ ! -L "$lower/$p" ]; then
          rm -f -- "$dst/$p" && echo "etc-overlay: removed /etc/$p (deleted under the overlay)"
        fi
      done < "$list"
    fi
    while IFS= read -r -d "" p; do
      case "$p" in .clean | static) continue ;; esac
      if [ -e "$lower/$p" ] || [ -L "$lower/$p" ]; then continue; fi
      if [ -c "$p" ] && [ "$(stat -c %t:%T -- "$p")" = 0:0 ]; then
        rm -f -- "$dst/$p" && echo "etc-overlay: removed /etc/$p (deleted under the overlay)"
        continue
      fi
      if (cd "$content" && cp -a --parents --remove-destination -- "$p" "$dst/"); then
        n=$((n + 1))
        echo "etc-overlay: carried out /etc/$p"
      else
        echo "etc-overlay: FAILED to carry out /etc/$p" >&2
      fi
    done < <(find . -mindepth 1 ! -type d -printf '%P\0')
    echo "etc-overlay: carried $n file(s) from $upper into $dst"
  '';
}
