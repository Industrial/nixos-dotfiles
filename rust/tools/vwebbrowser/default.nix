# vwebbrowser as a Nix package (buildRustPackage, dependencies vendored from
# the checked-in Cargo.lock). build.rs compiles src/*.vlt with Voltaic as a
# library, so no voltaic binary is needed here.
#
# The system libraries follow nixpkgs' epiphany (pkgs/by-name/ep/epiphany),
# the reference WebKitGTK 6.0 browser: glib-networking for TLS, GStreamer
# base/good/bad/libav for HTML5 audio and video. wrapGAppsHook4 puts the GIO
# modules, the GStreamer plugin path and the GSettings schemas in the
# wrapper's environment.
{
  lib,
  rustPlatform,
  pkg-config,
  wrapGAppsHook4,
  webkitgtk_6_0,
  gtk4,
  glib,
  glib-networking,
  libsoup_3,
  gst_all_1,
}:
rustPlatform.buildRustPackage {
  pname = "vwebbrowser";
  version = "0.0.1";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./Cargo.toml
      ./Cargo.lock
      ./build.rs
      ./src
    ];
  };

  cargoLock.lockFile = ./Cargo.lock;

  nativeBuildInputs = [
    pkg-config
    wrapGAppsHook4
  ];

  buildInputs = [
    webkitgtk_6_0
    gtk4
    glib
    glib-networking
    libsoup_3
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-libav
  ];

  # The tests are the Voltaic `test` blocks: run_test with a fake window, no
  # display and no gtk::init.

  meta = {
    description = "A minimal WebKitGTK browser on Voltaic + id_effect";
    license = lib.licenses.mit;
    mainProgram = "vwebbrowser";
    platforms = lib.platforms.linux;
  };
}
