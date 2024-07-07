{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    nushell
  ];
  # TODO: NuShell requires write access to these files
  # system = {
  #   activationScripts = {
  #     linkFile = {
  #       text = ''
  #         mkdir -p /home/${settings.username}/.config/nushell
  #         ln -sf ${pkgs.writeTextFile {
  #           name = "config.nu";
  #           text = builtins.readFile ./.config/nushell/config.nu;
  #         }} /home/${settings.username}/.config/nushell/config.nu
  #         ln -sf ${pkgs.writeTextFile {
  #           name = "env.nu";
  #           text = builtins.readFile ./.config/nushell/env.nu;
  #         }} /home/${settings.username}/.config/nushell/env.nu
  #       '';
  #     };
  #   };
  # };
}
