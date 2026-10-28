# V-268138 (CAT II) — NixOS must not allow direct login to the root account.
#
# Fix text: users.mutableUsers = false;
#
# The mechanism is indirect but sound on NixOS: with mutableUsers off, every account's
# password comes from the configuration, and root is declared without one, so there is no
# password to log in with. `passwd` also stops working for everyone.
#
# `full` profile, and it is the single most intrusive control in the set for day-to-day use:
# every user password must be declared in Nix (hashedPasswordFile, or agenix/asecret on this
# fleet) before activation, or the account becomes unusable. Applying it without first
# provisioning those secrets locks you out of your own machine.
{...}: {
  users.mutableUsers = false;
}
