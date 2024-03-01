# thanks to its declarative configuration
# it's remarkbly simple to publish a website or serve
# SSH connections on NixOS, with Onion service, I2P Destination and
# Yggdrasil
# These connections, in contrast to the underlying network,
# is not limited by any existing barriers such as
# Carrier Grade NAT or firewalls.
# (Strict firewall only allowing 443,80,DNS needs some more
#  configuration, though)
# Example: two computers in two different locations, connected to the
# internet via IPv4-only with NAT. (e.g. 10.8.9.1 and 192.168.122.124)
#
# Enable any of these three services with SSH tunnel and SSH server.
#
# The service will generate a globally unique address for each tunnel.
#
# The two computers can then be connected via SSH:
#
# Onion Service:
# ssh -o ProxyCommand="nc -x [::1]:9050 %h %p" \
#     -o IdentityFile=~/.ssh/<priv_key> \
#     -p <port> \
#     <user>@<onion_service_address.onion>
#
# I2P Destination:
# ssh -o ProxyCommand="nc -x [::1]:4447 %h %p" \
#     -o IdentityFile=~/.ssh/<priv_key> \
#     <user>@<i2p_hash.b32.i2p>
#
# There is no need to specify port of a I2P Destination/Site/Service,
# the client will automatically determine the port from which the service is
# available. That is, the service is **always** accessible from **bare** I2P
# address no matter the value given in "services.i2pd.inTunnels.<name>.inPort".
#
# Yggdrasil network: uses normal IPv6 address, no
# proxy needed
# ssh -o IdentityFile=~/.ssh/<priv_key> \
#     -p <port> \
#     <user>@[<Yggdrasil network address>]
{
  settings,
  config,
  pkgs,
  ...
}: {
  # Note on services on yggdrasil: for every service, you need to
  # open ports in firewall:
  # in this example:
  # webserver on 63333
  # ssh on 23849
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      # yggdrasil only, not needed for i2p or onion
      #  webserver
      63333
      #  ssh
      23849
      # yggdrasil listen port
      39354
      # i2p port
      29392
    ];
    allowedUDPPorts = [
      # i2p port
      29392
    ];
  };

  # Configure SSH server
  services.openssh = {
    enable = true;
    ports = [
      22
      23849
      # add other ports if needed
    ];

    # If port is not specified for address sshd will
    # listen on all ports specified by ports option.
    #
    # will override default listening on all
    # local addresses and port 22.
    #
    # won't automatically enable given
    # ports in firewall configuration.
    # customize port for yggdrasil if needed
    listenAddresses = [
      # i2p and onion connects from localhost ([::1])
      {
        addr = "[::1]";
        port = 23849;
      }
      #{ addr = "<yggdrasil-addr>"; port = <integer>; }
    ];

    allowSFTP = true;
    openFirewall = true;

    settings = {
      PasswordAuthentication = false;
    };
  };

  users.users.root.openssh.authorizedKeys.keys = [
    # generate with: ssh-keygen -t ed25519
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMPjbvmfypoGAL9zNUfaaJldFj0zY3Xx668y3M38b7FW tom@langhus"
  ];

  services.tor = {
    enable = true;
    enableGeoIP = false;
    client = {
      enable = true;
      dns.enable = true;
      socksListenAddress = {
        IsolateDestAddr = true;
        addr = "[::1]";
        port = 9050;
      };
    };
    relay = {
      #Don’t run a relay and service at the same time
      enable = false;
      role = "private-bridge";
    };
    relay.onionServices = {
      "service0" = {
        version = 3;
        map = [
          # static web server
          {
            port = 80;
            target = {
              addr = "[::1]";
              port = 63333;
            };
          }
          # ssh server
          {
            port = 22;
            target = {
              addr = "[::1]";
              port = 23849;
            };
          }
          # add ports for other services, or create a new onion
          # service block
        ];
      };
    };
    settings = {
      ClientUseIPv4 = true;
      ClientUseIPv6 = true;
      ClientPreferIPv6ORPort = true;
      UpdateBridgesFromAuthority = 1;
      UseEntryGuards = 1;
      #Sandbox = true; # not compatible with obfs4proxy and #ClientTransportPlugin
      SafeSocks = 1;
      NoExec = 1;
      # if your network is censored, use bridges:
      # get bridges from https://bridges.torproject.org/options
      # yggdrasil also has bridges:
      # see https://yggdrasil-network.github.io/services.html
      UseBridges = 1;
      ClientTransportPlugin = "obfs4 exec ${pkgs.obfs4}/bin/obfs4proxy";
      Bridge = [
        "[21b:321:3243:ecb6:a4cf:289c:c0f1:d6eb]:16728 835FFE642EFA3BB7936663D2365A15D319FB6226"
        "[21f:5234:5548:31e5:a334:854b:5752:f4fc]:9770 6C4C89ABE4D06987AB1F51C06939410282A1BF58"
        "[224:6723:7ae0:5655:e600:51c9:4300:a2fb]:9001 F873E91048B40656694BE94ACAB6F0D32CAF8E17"
        "obfs4 [218:4feb:a509:9db2:2b34:6e7e:e071:5dee]:1992 F805F6B4E5E203EFE2A7FFB1E5042AFE8BD986B4 cert=0GcjnEnZ0rJ8/nfxo4ZSkjMZ0fqHSrvj/MdwEtbbuzx8qgqFTaqHTuWelGw2MxJ5wW2QaQ iat-mode=0"
      ];
    };
    openFirewall = true;
  };

  # webserver
  # it's best to serve static content only to preserve anonymity
  # no Javascript!!!
  services.httpd = {
    enable = true;
    logPerVirtualHost = true;
    adminAddr = "test@example.org";
    # remove sensitive server info
    extraConfig = ''
      ServerTokens Prod
      ServerSignature Off
    '';
    virtualHosts = {
      site0 = {
        listen = [
          {
            ip = "localhost";
            port = 63333;
            ssl = false;
            #onion, i2p, and yggdrasil are e2e encrypted
            #by design.
          }
        ];
        documentRoot = "/srv/site0";
      };
    };
  };

  services.i2pd = {
    enable = true;
    enableIPv4 = true;
    enableIPv6 = true;
    bandwidth = 1024;
    port = 29392;
    proto = {
      http = {
        # web admin; available on localhost
        port = 7071;
        enable = true;
      };
      socksProxy.port = 4447;
      socksProxy.enable = true;
    };
    outTunnels = {
      # connect to mail services by postman
      # available at http://hq.postman.i2p
      smtp-postman = {
        enable = true;
        address = "::1";
        destinationPort = 7659;
        destination = "smtp.postman.i2p";
        port = 7659;
      };
      pop-postman = {
        enable = true;
        address = "::1";
        destinationPort = 7660;
        destination = "pop.postman.i2p";
        port = 7660;
      };
    };
    floodfill = true;
    inTunnels = {
      ssh-server = {
        enable = true;
        address = "::1";
        destination = "::1";
        # optimize ssh connection; but decreases anonymity
        inbound.length = 1;
        outbound.length = 1;
        inbound.quantity = 10;
        outbound.quantity = 10;
        port = 23849;
        accessList = []; # restrict access to specific clients
      };
      www-site0 = {
        enable = true;
        address = "::1";
        destination = "::1";
        inbound.length = 3;
        outbound.length = 3;
        inbound.quantity = 5;
        outbound.quantity = 5;
        port = 63333; # httpd port
      };
    };
  };

  services.yggdrasil = {
    enable = true;
    openMulticastPort = true;
    persistentKeys = true;
    settings = {
      # generate fresh new config with: yggdrasil -genconf
      InterfacePeers = {};
      # to run a public peer, just add this line
      #Listen = [ "tls://[::]:12345" ];
      #then add firewall
      Listen = [];
      AdminListen = "unix:///var/run/yggdrasil/yggdrasil.sock";
      MulticastInterfaces = [
        {
          Regex = ".*";
          Beacon = true;
          Listen = true;
          Port = 0;
        }
      ];
      LinkLocalTCPPort = 39354;
      AllowedPublicKeys = [];
      IfName = "auto";
      IfMTU = 65535;
      NodeInfoPrivacy = false;
      # if 'yggdrasilctl getpeers' returns no peers
      # you have to add some your self
      # see https://publicpeers.neilalexander.dev/
      # and
      # https://github.com/yggdrasil-network/public-peers/tree/master/other
      # for tor and i2p peers
      Peers = [
        "tls://ygg0.ezdomain.ru:11130"
        "tls://yggpvs.duckdns.org:8443"
        "tcp://y.zbin.eu:7743"
        "tls://bazari.sh:3725"
        "socks://localhost:4447/7mx6ztmimo5nrnmydjjtkr6maupknr3zlyr33umly22pqnivyxcq.b32.i2p:46944"
        "socks://localhost:4447/gqt6l2wox5jndysfllrgdr6mp473t24mdi7f3iz6lugpzv3z67wq.b32.i2p:63412"
        "socks://localhost:4447/i6lbsjw7kh4gqmbylcsjtfh3juj3dbbk24bwzrpgvtalhs7xagoa.b32.i2p:2721"
      ];
    };
  };

  # after applying the settings with 'nixos-rebuild switch'
  # get addresses from
  # onion service:   /var/lib/tor/onion/<name>/hostname
  # i2p destination: http://localhost:7071/?page=i2p_tunnels
  # yggdrasil:       yggdrasilctl getself
  # yggdrasil:       ip address show tun0
}
