{pkgs, ...}: {
  discord = import ./discord/discord.test.nix {inherit pkgs;};
  fractal = import ./fractal/fractal.test.nix {inherit pkgs;};
  teams = import ./teams/teams.test.nix {inherit pkgs;};
  telegram = import ./telegram/telegram.test.nix {inherit pkgs;};
  weechat = import ./weechat/weechat.test.nix {inherit pkgs;};
}
