# nmtui - NetworkManager Text User Interface
# Interactive TUI for NetworkManager (comes with NetworkManager package)
# Note: Not Rust-based (C), but it's the standard interactive NetworkManager TUI
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # nmtui comes with NetworkManager
    # Usage: nmtui
    # Interactive menu-driven interface for WiFi/VPN management
    networkmanager
  ];

  # nmtui is available at: /run/current-system/sw/bin/nmtui
  # No need to install separately - comes with networkmanager package
}
