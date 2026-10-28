# V-268158 (CAT II) — NixOS must protect against or limit the effects of denial-of-service
# attacks by implementing rate-limiting measures on impacted network interfaces.
#
# Fix text adds three hashlimit rules via networking.firewall.extraCommands. Transcribed as
# published, including the `ip46tables` helper NixOS provides.
#
# This control is why it is in `full` and not base-safe, and the reason is the SSH rule:
#
#   --dport 22 ... --hashlimit-above 1000000b/second --jump nixos-fw-refuse
#
# That REFUSES SSH traffic above 1 MB/s from a single source address. Large scp and rsync
# transfers over SSH exceed it immediately, so a host with this rule drops its own fleet
# transfers. The original triage classified this control as zero-cost on the assumption it
# merely enabled the firewall; reading the fix text corrected that.
#
# The 80/443 rules are connection-rate limits at 1000/minute and are harmless here — this
# fleet serves no public HTTP — but they are kept because the published rule set is what the
# check greps for.
{...}: {
  networking.firewall.enable = true;

  networking.firewall.extraCommands = ''
    ip46tables --append INPUT --protocol tcp --dport 22 --match hashlimit --hashlimit-name stig_byte_limit --hashlimit-mode srcip --hashlimit-above 1000000b/second --jump nixos-fw-refuse
    ip46tables --append INPUT --protocol tcp --dport 80 --match hashlimit --hashlimit-name stig_conn_limit --hashlimit-mode srcip --hashlimit-above 1000/minute --jump nixos-fw-refuse
    ip46tables --append INPUT --protocol tcp --dport 443 --match hashlimit --hashlimit-name stig_conn_limit --hashlimit-mode srcip --hashlimit-above 1000/minute --jump nixos-fw-refuse
  '';
}
