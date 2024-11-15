{pkgs, ...}: {
  services = {
    xserver = {
      enable = true;

      # TODO: Set these
      # autoRepeatDelay
      # autoRepeatInterval

      displayManager = {
        session = [
          {
            manage = "desktop";
            name = "xterm";
            start = ''
              ${pkgs.xterm}/bin/xterm -ls &
              waitPID=$!
            '';
          }
        ];
      };
    };
  };
}
