{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    android-studio
    android-tools
    # android-sdk
    # android-ndk
    # gradle
    # kotlin
    # flutter
  ];
}
