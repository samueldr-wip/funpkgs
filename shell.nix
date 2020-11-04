let
  nixpkgs = import (fetchNixpkgs {
    rev = "1dc37370c489b610f8b91d7fdd40633163ffbafd";
    sha256 = "1qvfxf83rya7shffvmy364p79isxmzcq4dxa0lkm5b3ybicnd8f4";
  }) {};

  fetchNixpkgs = {rev, sha256}: fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/${rev}.tar.gz";
    inherit sha256;
  };

  nixWrapper = nixpkgs.writeShellScriptBin "nix" ''
    exec env -i ${nixpkgs.nix}/bin/nix --option sandbox-paths "" "$@"
  '';

  nix-buildWrapper = nixpkgs.writeShellScriptBin "nix-build" ''
    exec env -i ${nixpkgs.nix}/bin/nix-build --option sandbox-paths "" "$@"
  '';
in
  nixpkgs.mkShell {
    buildInputs = [
      nix-buildWrapper
      nixWrapper
    ];
  }
