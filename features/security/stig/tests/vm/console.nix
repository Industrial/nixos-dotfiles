# Test-driver helpers for logging on at a virtual console and reading the pam_faillock
# tally: Python source, spliced into a test script that drives a node called `machine`.
#
# Shared by ./pam.nix (V-268081 on a minimal machine) and ../test-host-logon.nix (the same
# control on muninn's own configuration), so both type at a real getty the same way.
#
# The helpers synchronise on the END of the screen, never on a count of what is on it. The
# consent banner (V-268082) is longer than the screen, and a screen that has scrolled no
# longer holds what was counted.
''
  import re


  def screen_ends_with(tty, suffix):
      for _ in range(120):
          if machine.get_tty_text(tty).rstrip().endswith(suffix):
              return
          machine.sleep(1)
      raise Exception(f"tty{tty} never showed '{suffix}':\n{machine.get_tty_text(tty)}")


  def type_logon(tty, user, password):
      """One logon attempt at the getty on `tty`. Returns once the password is sent."""
      machine.succeed(f"chvt {tty}")
      screen_ends_with(tty, "login:")
      machine.send_chars(user + "\n")
      screen_ends_with(tty, "Password:")
      machine.send_chars(password + "\n")


  def refused(tty, user, password):
      """A logon attempt that must end back at the login prompt, with no session."""
      type_logon(tty, user, password)
      screen_ends_with(tty, "login:")
      machine.fail(f"pgrep -t tty{tty} -u {user}")


  def accepted(tty, user, password):
      """A logon attempt that must end in a session owned by `user` on that console."""
      type_logon(tty, user, password)
      machine.wait_until_succeeds(f"pgrep -t tty{tty} -u {user}", timeout=60)


  def failures(user):
      """Recorded failed attempts, as `faillock --user` reports them."""
      out = machine.succeed(f"faillock --user {user}")
      return len([line for line in out.splitlines() if re.match(r"\d{4}-\d\d-\d\d ", line)])
''
