# DNSCrypt with Quad9 upstream
# Check if the service is running:
#   systemctl status dnscrypt-proxy2
# Test DNS Resolution:
#   nix-shell -p dnsutils --run "dig example.com @127.0.0.1"
# Test Malware Blocking:
#   nix-shell -p dnsutils --run "dig malware.testcategory.com @127.0.0.1"
# Verify DNSSEC:
#   nix-shell -p dnsutils --run "dig +dnssec example.com @127.0.0.1"
{
  settings,
  lib,
  ...
}: {
  networking = {
    nameservers = ["127.0.0.1" "::1"];
    search = ["${settings.hostname}"];
  };

  services = {
    dnscrypt-proxy2 = {
      enable = true;
      settings = {
        ipv6_servers = true;
        block_ipv6 = false;
        require_dnssec = true;

        # Use Quad9 servers
        server_names = [
          "quad9-dnscrypt-ip4-filter-pri"
          "quad9-dnscrypt-ip4-filter-alt"
        ];

        sources = {
          # Use Quad9's resolver list
          quad9-resolvers = {
            urls = [
              "https://quad9.net/dnscrypt/quad9-resolvers.md"
              "https://raw.githubusercontent.com/Quad9DNS/dnscrypt-settings/main/dnscrypt/quad9-resolvers.md"
            ];
            cache_file = "/var/lib/dnscrypt-proxy/quad9-resolvers.md";
            minisign_key = "RWQBphd2+f6eiAqBsvDZEBXBGHQBJfeG6G+wJPPKxCZMoEQYpmoysKUN";
            refresh_delay = 72;
            prefix = "quad9-";
          };
        };
      };
    };
  };

  systemd = {
    services = {
      dnscrypt-proxy2 = {
        serviceConfig = {
          StateDirectory = "dnscrypt-proxy";
        };
      };
    };
  };
}
