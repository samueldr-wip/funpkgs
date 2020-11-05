let
  nixpkgs = import (fetchNixpkgs {
    rev = "1dc37370c489b610f8b91d7fdd40633163ffbafd";
    sha256 = "1qvfxf83rya7shffvmy364p79isxmzcq4dxa0lkm5b3ybicnd8f4";
  }) {};

  fetchNixpkgs = {rev, sha256}: fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/${rev}.tar.gz";
    inherit sha256;
  };

  # Completely clear the sandbox when in the nix-shell.
  options = '' --option sandbox-paths ""'';

  nixWrapper = nixpkgs.writeShellScriptBin "nix" ''
    exec env -i ${nixpkgs.nix}/bin/nix ${options} "$@"
  '';
  nix-buildWrapper = nixpkgs.writeShellScriptBin "nix-build" ''
    exec env -i ${nixpkgs.nix}/bin/nix-build ${options} "$@"
  '';

  dependencies = ((import ./.).
    runExecline "nothing" {} ''
      false
    '').dependencies
  ;
in
  nixpkgs.mkShell {
    # Forces dependencies to be built
    # Ugly, but effective.
    # This is because the dependencies *do* need the sandbox to contain /bin/sh!
    shellHook = ''
      # ${builtins.concatStringsSep " ; " dependencies}
    '';
    buildInputs = [
      nix-buildWrapper
      nixWrapper
    ];
  }
