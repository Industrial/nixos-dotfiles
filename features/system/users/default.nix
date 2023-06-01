{...}: {
  users.users.tom.isNormalUser = true;
  users.users.tom.home = "/home/tom";
  users.users.tom.description = "Tom Wieland";
  users.users.tom.extraGroups = [
    "audio"
    "networkmanager"
    "plugdev"
    "wheel"
    # "vboxusers"
  ];
  # users.extraGroups.vboxusers.members = ["tom"];
}
