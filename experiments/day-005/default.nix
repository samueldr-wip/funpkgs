let
  inherit (import ./support {
    system = builtins.currentSystem;
  })
  runExecline
  externalSrc
  tinycc
  ;

  _boot = import ./boot.nix {
    inherit
      externalSrc
      runExecline
      tinycc
    ;
  };

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

  # Ugly utility to bunch up foreground commands
  commands = cmds: builtins.concatStringsSep "\n" (builtins.map (cmd: ''
    foreground {
      echo " $" ${cmd}
    }
    ifelse -n { ${cmd} } {
      foreground {
        echo "\n(Command failed)"
      }
      # FIXME: get actual return code
      exit 1
    }
  '') cmds);
  header = text: ''
    foreground {
      printf "\n:: ${text}\n"
    }
  '';

  heirloom-sh = runExecline "heirloom-sh" {
    src = externalSrc.heirloom;
    CC = "${tinycc}/bin/tcc";
    PATH="${_boot.netbsd-make}/bin";
  } ''
    importas out out
    importas src src
    importas CC CC

    ${header "Source phase"}
    ${commands [
      "cp -vr \${src}/heirloom-sh /build/src"
    ]}
    execline-cd /build/src

    ${header "Patch phase"}
    ${commands [
      "patch -p2 -i ${./heirloom/0001-heirloom-sh-Work-around-tcc-compilation-bug.patch}"
    ]}

    ${header "Build phase"}
    ${commands [
      "make CC=\${CC} sh"
      "make CC=\${CC} sh.1.out"
    ]}

    ${header "Install phase"}
    ${commands [
      # Not using `make install` as it is way too "old UNIX" style.
      "mkdir -p \${out}/bin \${out}/share/man/man1"
      "cp -v sh \${out}/bin/sh"
      "ln -s \${out}/bin/sh \${out}/bin/rsh"
      "ln -s \${out}/bin/sh \${out}/bin/jsh"
      "cp -v sh.1.out \${out}/share/man/man1/sh.1"
    ]}
  '';

  netbsd = {
    make = runExecline "netbsd-make-9.0" rec {
      version = "9.0";
      src = externalSrc.netbsd.${version}.make;
      mksys = externalSrc.netbsd.${version}.mk;
      CC = "${tinycc}/bin/tcc";
      CFLAGS='' -D_PATH_DEFSYSPATH=\"''${out}/share/mk\" -D_PATH_DEFSHELLDIR=\"${heirloom-sh}/bin/\" '';
    } ''
      importas out out
      importas src src
      importas mksys mksys
      importas CC CC
      importas CFLAGS CFLAGS

      foreground {
        printf "\n:: Source phase\n"
      }

      foreground {
        cp -vr ''${src}/usr.bin/make /build/src
      }

      execline-cd src

      ${commands  [
        "patch -p2 -i ${./netbsd/0001-make-Funpkgs-hacks.patch}"
      ]}

      foreground {
        printf "\n:: Build phase\n"
      }

      ${commands [
        #(builtins.map (src: "$CC -g -c ${src}") SRCS)
        "${_boot.netbsd-make}/bin/make USE_META=no CFLAGS=\${CFLAGS} CC=\${CC} make"
        # XXX: cannot run as it requires `diff` which we don't have yet.
        #"${_boot.netbsd-make}/bin/make USE_META=no CFLAGS=\${CFLAGS} CC=\${CC} test"
      ]}

      foreground {
        printf "\n:: Install phase\n"
      }

      ${commands [
        "${_boot.netbsd-make}/bin/make USE_META=no CFLAGS=\${CFLAGS} CC=\${CC} .TARGET=\${out} install"
        "mkdir -p \${out}/share/"
        # These are probably inappropriate in many ways.
        # Though sys.mk *is* needed.
        "cp -vr \${mksys}/share/mk \${out}/share/mk"
      ]}

      execline-cd ''${out}/share

      ${commands  [
        "patch -p1 -i ${./netbsd/0001-Funpkgs-hacks.patch}"
      ]}
    '';
  };


  test-make = runExecline "test-make" {
    src = ./test-make;
    CC = "${tinycc}/bin/tcc";
    PATH = "${tinycc}/bin";
  } ''
    importas out out
    importas src src
    importas CC CC

    foreground {
      printf "\n:: Source phase\n"
    }

    foreground {
      cp -vr ''${src} /build/src
    }

    execline-cd src

    foreground {
      printf "\n:: Build phase\n"
    }

    ${commands [
      "${netbsd.make}/bin/make -f Makefile CC=tcc hello"
      "./hello"
      "mkdir -p \${out}/bin"
      "cp -v hello \${out}/bin/hello"
    ]}
  '';

  lua = runExecline "lua-5.4.1" rec {
      version = "5.4.1";
      src = externalSrc.lua;
      PATH = "${tinycc}/bin";
    } ''
      importas out out
      importas src src
      importas CC CC

      foreground {
        printf "\n:: Source phase\n"
      }

      foreground {
        cp -vr ''${src} /build/src
      }

      execline-cd src

      foreground {
        printf "\n:: Build phase\n"
      }

      ${commands [
        "patch -p1 -i ${./lua/0001-Remove-dependency-on-readline-and-ar.patch}"
        "${netbsd.make}/bin/make CC=tcc lua"
        "mkdir -p \${out}/bin"
        "cp -v lua \${out}/bin/lua"
      ]}
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
      lua
      netbsd
      test-make

      runExecline
      externalSrc
    ;
  }
