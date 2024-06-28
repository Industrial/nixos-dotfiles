{...}: {
  system.activationScripts.shellInit.text = ''
    defaults write -g ApplePressAndHoldEnabled -bool false
    defaults write -g AppleInterfaceStyle Dark
    defaults write -g KeyRepeat -int 2
    defaults write -g InitialKeyRepeat -int 15
    defaults write -g AppleShowAllFiles -bool true
    defaults write -g NSAutomaticQuoteSubstitutionEnabled -bool false
    defaults write -g com.apple.gamed Disabled
  '';
}
