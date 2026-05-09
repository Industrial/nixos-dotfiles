# Browser: Chromium with Nix-managed policies and extensions.
# programs.chromium only writes config to /etc/chromium/ — the package must be in systemPackages.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    chromium
  ];

  programs.chromium = {
    enable = true;
    homepageLocation = "https://duckduckgo.com";
    extensions = [
      # Phantom (crypto wallet)
      "bfnaelmomeimhlpmgjnjophhpkkoljpa;https://clients2.google.com/service/update2/crx"
      # Rabby Wallet
      "acmacodkjbdgmoleebolmdjonilkdbch;https://clients2.google.com/service/update2/crx"
      # uBlock Origin
      "cjpalhdlnbpafiamejdnhcphjbkeiagm;https://clients2.google.com/service/update2/crx"
      # Privacy Badger (EFF)
      "pkehgijcmpdhfbdbbnkijodmdjhbjlgp;https://clients2.google.com/service/update2/crx"
      # Bitwarden
      "nngceckbapebfimnlniiiahkandclblb;https://clients2.google.com/service/update2/crx"
      # Enhancer for YouTube
      "ponfpcnoihfmfllpaingbgckeeldkhle;https://clients2.google.com/service/update2/crx"
    ];
  };

  # AdNauseam is not on the Chrome Web Store (banned by Google). Install manually:
  # 1. Download adnauseam.chromium.zip from https://github.com/dhowe/AdNauseam/releases
  # 2. Unzip, then in chromium: chrome://extensions → Developer mode → Load unpacked → select folder
}
