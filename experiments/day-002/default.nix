let
  inherit (import ./support {
    system = builtins.currentSystem;
  })
  runExecline
  ;

  banner = ''
    ▄▄▄▄▄▄▄▄                                ▄▄                           
    ██▀▀▀▀▀▀                                ██                           
    ██        ██    ██  ██▄████▄  ██▄███▄   ██ ▄██▀    ▄███▄██  ▄▄█████▄ 
    ███████   ██    ██  ██▀   ██  ██▀  ▀██  ██▄██     ██▀  ▀██  ██▄▄▄▄ ▀ 
    ██        ██    ██  ██    ██  ██    ██  ██▀██▄    ██    ██   ▀▀▀▀██▄ 
    ██        ██▄▄▄███  ██    ██  ███▄▄██▀  ██  ▀█▄   ▀██▄▄███  █▄▄▄▄▄██ 
    ▀▀         ▀▀▀▀ ▀▀  ▀▀    ▀▀  ██ ▀▀▀    ▀▀   ▀▀▀   ▄▀▀▀ ██   ▀▀▀▀▀▀  
                                  ██                   ▀████▀▀           
  '';

  # This derivation is not meant to be a stable output; thus the use of
  # `builtins.currentTime`.
  # It is used to check "correctly" what the sandbox looks like, and will fail
  # if /bin/sh is present.
  sandbox-exploration =
    let 
      # To get the paths to known `runExecline` dependencies, so we can filter
      # them out of our exploration.
      dummy = runExecline "dummy" {} "echo ok";
    in
    runExecline "sandbox-exploration" {} ''
    # ${toString builtins.currentTime}
    importas out out
    ifelse { test -e /bin/sh } { foreground { echo "/bin/sh exists in the sandbox... aborting!" } exit 1 }

    foreground {
      mkdir -vp $out
    }

    redirfd -a 1 ''${out}/out.txt
    foreground {
      find / ! (
        -path /proc
        -o -path /proc/*
        -o -path /dev
        -o -path /dev/*
        ${
          builtins.concatStringsSep (" ")
          (map (dep: "-o -path ${dep} -o -path ${dep}/*") dummy.dependencies)
        }
        -o -path /nix
        -o -path /nix/store
        -o -path $out
        -o -path ''${out}/*
      )
    }
  '';
in
  {
    ___000-fail = throw ''
      (No attribute given to root.)
      ${banner}
       Funpkgs shouldn't be built directly.
       Use `-A` to refer to an attribute.

       For the time being, why not try `nix-build -A hello-world`?
    '';

    inherit
      sandbox-exploration
    ;
  }
