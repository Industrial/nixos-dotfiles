{pkgs ? import <nixpkgs> {}}: let
  module = import ./settings.nix;
in {
  testBasicEvaluation = {
    expr = module {
      inherit (pkgs) system;
      hostname = "test-host";
    };
    expected = {
      system = pkgs.system;
      username = "tom";
      settings = {
        system = pkgs.system;
        hostname = "test-host";
        username = "tom";
        stateVersion = "24.11";
        hostPlatform = {
          system = pkgs.system;
        };
        userdir = "/home/tom";
        useremail = "tom@${pkgs.system}.local";
        userfullname = "tom";
      };
    };
  };

  testCustomUsername = {
    expr = module {
      inherit (pkgs) system;
      hostname = "test-host";
      username = "custom-user";
    };
    expected = {
      system = pkgs.system;
      username = "custom-user";
      settings = {
        system = pkgs.system;
        hostname = "test-host";
        username = "custom-user";
        stateVersion = "24.11";
        hostPlatform = {
          system = pkgs.system;
        };
        userdir = "/home/custom-user";
        useremail = "custom-user@${pkgs.system}.local";
        userfullname = "custom-user";
      };
    };
  };

  testCustomVersion = {
    expr = module {
      inherit (pkgs) system;
      hostname = "test-host";
      version = "23.11";
    };
    expected = {
      system = pkgs.system;
      username = "tom";
      settings = {
        system = pkgs.system;
        hostname = "test-host";
        username = "tom";
        stateVersion = "23.11";
        hostPlatform = {
          system = pkgs.system;
        };
        userdir = "/home/tom";
        useremail = "tom@${pkgs.system}.local";
        userfullname = "tom";
      };
    };
  };
}
