let
  # Piggy-back on Nixpkgs for static utilities for the time being.
  nixpkgs = import (fetchNixpkgs {
    rev = "1dc37370c489b610f8b91d7fdd40633163ffbafd";
    sha256 = "1qvfxf83rya7shffvmy364p79isxmzcq4dxa0lkm5b3ybicnd8f4";
  }) {};

  fetchNixpkgs = {rev, sha256}: fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/${rev}.tar.gz";
    inherit sha256;
  };

  pkgs = nixpkgs.pkgsStatic;
  targetPrefix = pkgs.stdenv.cc.targetPrefix;

  # Toybox provides our "coreutils" (no sh!)
  toybox = pkgs.toybox.overrideAttrs({
    patches ? [],
    makeFlags ? [],
    postPatch ? "",
    ...
  }: {
    patches = patches ++ [
      ./0001-Allow-toybox-binary-to-have-a-prefix-too.patch
    ];
    #src = ./toybox;

    postPatch = ''
      ${postPatch}

      export CC=${targetPrefix}cc
      export HOSTCC=${targetPrefix}cc
    '';

    makeFlags = makeFlags ++ [
      "HOSTCC=${targetPrefix}cc"
    ];

    allowedReferences = [];
  });

  # execline provides our scripting environment (no sh!)
  execline = pkgs.execline;
  # Make `execlineb` usable as a builder.
  execlineb = pkgs.runCommandNoCC "execlineb" {
    allowedReferences = [
      execline
    ];
  } ''
    cp -v ${execline}/bin/execlineb $out
  '';

  # Override the tinycc from Nixpkgs, making a static build with somewhat
  # controlled dependencies.
  # The glibc probably could do with being stripped from _its_ deps later on.
  tinycc = let stdenv = nixpkgs.makeStaticBinaries nixpkgs.stdenv; in
    (nixpkgs.tinycc.override {
      inherit stdenv;
    }).overrideAttrs({preConfigure ? "", ...}: {
      preConfigure = ''
        ${preConfigure}
        configureFlagsArray+=("--enable-static")
      '';
      # It fails... uh!
      doCheck = false;
      # And (somewhat) prevent regressions in dependencies.
      allowedReferences = [
        "out"
        stdenv.cc.libc
        stdenv.cc.libc.dev
      ];
    })
  ;
in
  {
    inherit
      execline
      execlineb
      tinycc
      toybox
    ;
  }

