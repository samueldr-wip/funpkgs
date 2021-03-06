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
  externalSrc.heirloom.sh = (nixpkgs.fetchzip {
    url = "mirror://sourceforge/heirloom/heirloom-sh/050706/heirloom-sh-050706.tar.bz2";
    sha256 = "0q9p9p0q64nj5fvsm2c47iv4kmdsg6kbynz4z3lbv3y7sy2b53h3";
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

