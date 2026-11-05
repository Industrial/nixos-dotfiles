# Terminal Session Manager.
#
# The layouts are GENERATED rather than copied in from etc/zellij/layouts/. Every pane's
# `cwd` used to be a literal /home/tom, which is wrong on any host whose user is not tom
# and silently so — zellij falls back to $HOME and the dashboard still looks fine. The
# repo's existing answer to that is `pkgs.writeTextFile` with settings interpolation
# (features/programming/git/default.nix generates gitconfig the same way);
# `pkgs.substituteAll` is used nowhere in this repo and is not introduced for this.
#
# Four named layouts, all opt-in: config.kdl sets `default_layout "default"`, so a bare
# `zellij` still gets zellij's own single pane.
#
#   zellij --layout system   the six-tab operations dashboard
#   zellij --layout dev      editor | shell / lazygit
#   zellij --layout agents   scratch / agent / http / sql, rooted at the dotfiles checkout
#   zellij --layout data     slumber beside lazysql
#
# `dev` and `data` declare no `cwd` at all, deliberately: their panes inherit the directory
# zellij was started in, so `cd ~/src/thing && zellij --layout dev` works and the layout is
# not pinned to one checkout. `system` and `agents` are dashboards for fixed locations and
# name theirs.
#
# Every `command` in every layout resolves from profiles/cli-core.nix or
# profiles/cli-desktop.nix, both of which every host carrying this feature imports
# (base.nix -> cli-core, desktop.nix -> cli-desktop). `nmtui` is the one command with no
# feature of its own: it comes from the NetworkManager package that
# features/nixos/networking puts on the system path.
#
# No pane in any layout gets image previews. yazi's terminal probe resolves at most
# kitty-graphics-old inside zellij and then drops even that once it detects a multiplexer,
# so the `dsk` pane is text, code, json and archive previews only — that holds under
# Ghostty too and is not a bug in this layout.
{
  settings,
  pkgs,
  ...
}: let
  zjstatus-hints = pkgs.fetchurl {
    url = "https://github.com/b0o/zjstatus-hints/releases/download/v0.1.4/zjstatus-hints.wasm";
    hash = "sha256-k2xV6QJcDtvUNCE4PvwVG9/ceOkk+Wa/6efGgr7IcZ0=";
  };

  dotfiles = "${settings.userdir}/.dotfiles";

  # Shared chrome for every layout: zellij's own tab-bar on top, zjstatus-hints below.
  #
  # The dashboard already used zjstatus-hints and the rescued `agents` layout used zellij's
  # built-in `zellij:status-bar`. zjstatus-hints wins everywhere, because config.kdl declares
  # it in `plugins` and loads it through `load_plugins` on every session: a layout drawing
  # `zellij:status-bar` instead would render a second status line, keyed to the zellij
  # defaults that `clear-defaults=true` has thrown away. One status line, and the one that
  # reports the keys this fleet actually binds.
  #
  # The plugin path is the same file config.kdl names, written absolutely rather than as `~`
  # so it derives from settings.userdir like everything else here.
  tabTemplate = ''
    default_tab_template {
      pane size=1 borderless=true {
        plugin location="zellij:tab-bar"
      }
      children
      pane size=1 borderless=true {
        plugin location="file:${settings.userdir}/.config/zellij/plugins/zjstatus-hints.wasm" {
          format_left "{mode} {tabs}"
          format_right "{pipe_zjstatus_hints}{datetime} "
          pipe_zjstatus_hints_format "{output}"
        }
      }
    }
  '';

  # KDL is indentation-insensitive and these files are store artifacts nobody hand-edits, so
  # the interpolated blocks start at column zero inside `layout` rather than being re-indented.
  withChrome = body: ''
    layout {
    ${tabTemplate}
    ${body}
    }
  '';

  mkLayout = name: text:
    pkgs.writeTextFile {
      name = "zellij-layout-${name}.kdl";
      inherit text;
    };

  # The operations dashboard, unchanged in shape from the hand-written system.kdl. Two edits:
  # every path now derives from settings.userdir, and the `dsk` tab runs yazi where it used to
  # run ranger. ranger stays in profiles/cli-core.nix; it is only no longer what the dashboard
  # opens.
  systemTabs = ''
    tab name="txt" {
      pane split_direction="vertical" {
        pane {
          cwd "${settings.userdir}"
        }
        pane {
          cwd "${settings.userdir}"
          command "calcurse"
        }
      }
    }

    tab name="sys" {
      pane split_direction="vertical" {
        pane split_direction="horizontal" {
          pane {
            cwd "${settings.userdir}"
            command "fastfetch"
          }
          pane {
            cwd "${settings.userdir}"
            command "lnav"
            args "-e" "journalctl -f"
          }
        }
        pane {
          cwd "${settings.userdir}"
          command "btop"
        }
      }
    }

    tab name="net" {
      pane split_direction="vertical" {
        pane split_direction="horizontal" {
          pane {
            cwd "${settings.userdir}"
            command "gping"
            args "google.com"
          }
          pane {
            cwd "${settings.userdir}"
            command "sudo"
            args "bandwhich"
          }
        }
        pane split_direction="horizontal" {
          pane {
            cwd "${settings.userdir}"
            command "nmtui"
          }
          pane {
            cwd "${settings.userdir}"
            command "bluetuith"
          }
        }
      }
    }

    tab name="dsk" {
      pane split_direction="vertical" {
        pane split_direction="horizontal" {
          pane {
            cwd "${settings.userdir}"
            command "broot"
          }
          pane {
            cwd "${settings.userdir}"
            command "yazi"
          }
        }
        pane split_direction="horizontal" {
          pane {
            cwd "${settings.userdir}"
            command "dust"
          }
          pane {
            cwd "${settings.userdir}"
            command "leaves"
          }
        }
      }
    }

    tab name="mda" {
      pane split_direction="vertical" {
        pane split_direction="horizontal" {
          pane {
            cwd "${settings.userdir}"
            command "pulsemixer"
          }
          pane {
            cwd "${settings.userdir}"
            command "spotify_player"
          }
        }

        pane split_direction="horizontal" {
          pane {
            cwd "${settings.userdir}"
            command "watch"
            args "-n" "2" "wpctl" "status"
          }
          pane {
            cwd "${settings.userdir}"
            command "usbtree"
          }
        }
      }
    }

    tab name="cfg" {
      pane split_direction="vertical" {
        pane split_direction="horizontal" {
          pane {
            cwd "${dotfiles}"
          }
          pane {
            cwd "${dotfiles}"
            command "lazygit"
          }
        }
        pane {
          cwd "${dotfiles}"
          command "nvim"
        }
      }
    }
  '';

  # Carried over verbatim from the hand-written system.kdl. A no-op under the current
  # config.kdl, which is `clear-defaults=true` and never binds Ctrl-q, but kept so the
  # dashboard still guards against a future default returning.
  systemKeybinds = ''

    keybinds {
      normal {
        unbind "Ctrl q"
      }
    }
  '';

  devTabs = ''
    tab name="dev" {
      pane split_direction="vertical" {
        pane size="60%" {
          command "nvim"
        }
        pane split_direction="horizontal" {
          pane
          pane {
            command "lazygit"
          }
        }
      }
    }
  '';

  # Rescued from the repo-root zellij.kdl that wave 0 deleted, with its /home/tom replaced.
  #
  # Its second tab ran `opencode`, and that command resolves on NO host: features/ai/opencode
  # exists but profiles/ai.nix has its import commented out and no host imports the feature
  # directly. A pane whose command is not on PATH is a dead pane, so the tab keeps its place
  # and its cwd and starts a shell instead. Putting opencode back is a profiles/ai.nix change,
  # not a layout one.
  agentsTabs = ''
    tab name="scratch" {
      pane {
        cwd "${dotfiles}"
      }
    }

    tab name="agent" {
      pane {
        cwd "${dotfiles}"
      }
    }

    tab name="http" {
      pane {
        cwd "${dotfiles}"
        command "slumber"
      }
    }

    tab name="sql" {
      pane {
        cwd "${dotfiles}"
        command "lazysql"
      }
    }
  '';

  # One tab, both tools side by side, and no cwd — slumber reads its request collection from
  # the working directory, so `data` is the layout you open inside a project where `agents` is
  # the one you open on the dotfiles checkout. The two tools are the same two tools; this is
  # the view, not a different toolset.
  dataTabs = ''
    tab name="data" {
      pane split_direction="vertical" {
        pane {
          command "slumber"
        }
        pane {
          command "lazysql"
        }
      }
    }
  '';
in {
  environment = {
    systemPackages = with pkgs; [
      zellij
      wl-clipboard # Wayland clipboard support for zellij
    ];
    etc = {
      "zellij/config.kdl" = {
        source = ./etc/zellij/config.kdl;
      };
      "zellij/layouts/system.kdl" = {
        source = mkLayout "system" (withChrome systemTabs + systemKeybinds);
      };
      "zellij/layouts/dev.kdl" = {
        source = mkLayout "dev" (withChrome devTabs);
      };
      "zellij/layouts/agents.kdl" = {
        source = mkLayout "agents" (withChrome agentsTabs);
      };
      "zellij/layouts/data.kdl" = {
        source = mkLayout "data" (withChrome dataTabs);
      };
      "zellij/plugins/zjstatus-hints.wasm" = {
        source = zjstatus-hints;
      };
    };
  };

  system = {
    activationScripts = {
      linkZellijConfig = {
        text = ''
          mkdir -p ${settings.userdir}/.config/zellij/layouts
          mkdir -p ${settings.userdir}/.config/zellij/plugins
          ln -sf /etc/zellij/config.kdl ${settings.userdir}/.config/zellij/config.kdl
          for layout in agents data dev system; do
            ln -sf /etc/zellij/layouts/$layout.kdl ${settings.userdir}/.config/zellij/layouts/$layout.kdl
          done
          ln -sf /etc/zellij/plugins/zjstatus-hints.wasm ${settings.userdir}/.config/zellij/plugins/zjstatus-hints.wasm
        '';
      };
    };
  };
}
