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
  toybox = (pkgs.toybox.override({ extraConfig = ''
      CONFIG_DIFF=y
      CONFIG_EXPR=y
    ''; })).overrideAttrs({
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

  # For now we're using fetchcvs from Nixpkgs.
  # We should rather use tarballs or other Nix builtins.
  # <pkgs/os-specific/bsd/netbsd/default.nix>
  fetchNetBSD = path: version: sha256: nixpkgs.fetchcvs {
    cvsRoot = ":pserver:anoncvs@anoncvs.NetBSD.org:/cvsroot";
    module = "src/${path}";
    inherit sha256;
    tag = "netbsd-${nixpkgs.lib.replaceStrings ["."] ["-"] version}-RELEASE";
  };

  externalSrc.netbsd."9.0".libutil = (fetchNetBSD "lib/libutil" "9.0" "02gm5a5zhh8qp5r5q5r7x8x6x50ir1i0ncgsnfwh1vnrz6mxbq7z");
  externalSrc.netbsd."9.0".make =    (fetchNetBSD "usr.bin/make" "9.0" "09szl3lp9s081h7f3nci5h9zc78wlk9a6g18mryrznrss90q9ngx");
  externalSrc.netbsd."9.0".mk =      (fetchNetBSD "share/mk" "9.0" "1gnz5mazr339dnjkwvsknfylpy2rcf1im3klxi9ddx69xspmcbn9");
  externalSrc.miniyacc = (nixpkgs.fetchgit {
    url = "https://c9x.me/git/miniyacc.git";
    rev = "60d16fd50aaaf4fec3014376f14cea62cb9aa5a9";
    sha256 = "1rqi4mzx0z1wp39n52v1l2b9ibbzkawz5gd5dpxz9lf3lcfynqaj";
  });
  externalSrc.heirloom = (nixpkgs.fetchFromGitHub {
    repo = "heirloom-mirror";
    owner = "samueldr";
    rev = "fd6e4b95c110a5cfa1edbc1526edab7b8d1d7c42";
    sha256 = "148ia569fssakqfa3p8ijmp2acrjh10phc9h7x0scph831hq3bjg";
  });
  externalSrc.lua = (nixpkgs.fetchFromGitHub {
    repo = "lua";
    owner = "lua";
    rev = "v5.4.1";
    sha256 = "0cn5kvmjrgq1pk1np2d2k63hkak1y3nalbmdk352dvm77gpvgjwd";
  });
in
  {
    inherit
      execline
      execlineb
      tinycc
      toybox

      externalSrc
    ;
  }

