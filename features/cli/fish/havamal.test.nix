{pkgs, ...}: let
  mockPkgs = {
    fishPlugins = {
      buildFishPlugin = attrs: {
        pname = attrs.pname;
        version = attrs.version;
        src = attrs.src;
        buildPhase = attrs.buildPhase;
        meta = attrs.meta;
      };
    };
    fetchFromGitHub = attrs: {
      owner = attrs.owner;
      repo = attrs.repo;
      rev = attrs.rev;
      sha256 = attrs.sha256;
    };
    lib = {
      licenses = {
        unlicense = "Unlicense";
      };
      maintainers = {
        Industrial = "Industrial";
      };
    };
  };

  havamalPlugin = import ./havamal.nix {pkgs = mockPkgs;};
in {
  # Test that the plugin is created with correct attributes
  testPluginAttributes = {
    expr = havamalPlugin.pname;
    expected = "Hávamál";
  };

  # Test that the plugin has the correct version
  testPluginVersion = {
    expr = havamalPlugin.version;
    expected = "v0.3.1";
  };

  # Test that the source is fetched correctly
  testSourceFetch = {
    expr = {
      owner = havamalPlugin.src.owner;
      repo = havamalPlugin.src.repo;
      rev = havamalPlugin.src.rev;
    };
    expected = {
      owner = "Industrial";
      repo = "havamal-bash";
      rev = "v0.3.1";
    };
  };

  # Test that the buildPhase contains the expected commands
  testBuildPhase = {
    expr = builtins.match ".*mkdir -p.*cp -r.*" havamalPlugin.buildPhase;
    expected = ["mkdir -p $out/share/fish/stanzas\ncp -r $src/stanzas/* $out/share/fish/stanzas/"];
  };

  # Test that the meta information is correct
  testMetaInfo = {
    expr = {
      description = havamalPlugin.meta.description;
      license = havamalPlugin.meta.license;
    };
    expected = {
      description = "Prints a random havamal stanza";
      license = "Unlicense";
    };
  };
}
