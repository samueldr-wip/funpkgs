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

  # TODO: re-build here using _boot helpers.
  heirloom-sh = _boot.heirloom-sh;

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

  # An heirloom-sh that's being built without external utilities.
  heirloom-sh = runExecline "heirloom-sh" {
    src = externalSrc.heirloom.sh;
    CC = "${tinycc}/bin/tcc";
  } ''
    importas out out
    importas src src
    importas CC CC

    foreground {
      printf "\n:: Source phase\n"
    }

    ${commands [
      "cp -vr \${src} /build/src"
    ]}

    execline-cd src

    ${commands [
      "patch -p2 -i ${./heirloom/0001-heirloom-sh-Work-around-tcc-compilation-bug.patch}"
    ]}

    foreground {
      printf "\n:: Build phase\n"
    }

    ${
      let
        CFLAGS = "-D_GNU_SOURCE -D_FILE_OFFSET_BITS=64L";
        LDFLAGS = "";
      in
      commands [
      "$CC ${CFLAGS} -c args.c"
      "$CC ${CFLAGS} -c blok.c"
      "$CC ${CFLAGS} -c bltin.c"
      "$CC ${CFLAGS} -c cmd.c"
      "$CC ${CFLAGS} -c ctype.c"
      "$CC ${CFLAGS} -c defs.c"
      "$CC ${CFLAGS} -c echo.c"
      "$CC ${CFLAGS} -c error.c"
      "$CC ${CFLAGS} -c expand.c"
      "$CC ${CFLAGS} -c fault.c"
      "$CC ${CFLAGS} -c func.c"
      "$CC ${CFLAGS} -c hash.c"
      "$CC ${CFLAGS} -c hashserv.c"
      "$CC ${CFLAGS} -c io.c"
      "$CC ${CFLAGS} -c jobs.c"
      "$CC ${CFLAGS} -c macro.c"
      "$CC ${CFLAGS} -c main.c"
      "$CC ${CFLAGS} -c msg.c"
      "$CC ${CFLAGS} -c name.c"
      "$CC ${CFLAGS} -c print.c"
      "$CC ${CFLAGS} -c pwd.c"
      "$CC ${CFLAGS} -c service.c"
      "$CC ${CFLAGS} -c setbrk.c"
      "$CC ${CFLAGS} -c stak.c"
      "$CC ${CFLAGS} -c string.c"
      "$CC ${CFLAGS} -c test.c"
      "$CC ${CFLAGS} -c ulimit.c"
      "$CC ${CFLAGS} -c word.c"
      "$CC ${CFLAGS} -c xec.c"
      "$CC ${CFLAGS} -c gmatch.c"
      "$CC ${CFLAGS} -c getopt.c"
      "$CC ${CFLAGS} -c strsig.c"
      "$CC ${CFLAGS} -c version.c"
      "$CC ${CFLAGS} -c mapmalloc.c"
      "$CC ${CFLAGS} -c umask.c"
      "$CC ${LDFLAGS} args.o blok.o bltin.o cmd.o ctype.o defs.o echo.o error.o expand.o fault.o func.o hash.o hashserv.o io.o jobs.o macro.o main.o msg.o name.o print.o pwd.o service.o setbrk.o stak.o string.o test.o ulimit.o word.o xec.o gmatch.o getopt.o strsig.o version.o mapmalloc.o umask.o  -o sh"
    ]}

    foreground {
      printf "\n:: Check phase\n"
    }

    ${commands [
      ''./sh -c "type echo"''
      ''./sh -c "echo ok"''
      ''./sh -c "echo ok > out.txt"''
      ''./sh -c "cat out.txt"''
      ''./sh -c "echo one two three"''

      # This broke at some point; any directory available.
      # See patch.
      ''./sh -c "echo /tmp/"''
    ]}

    foreground {
      printf "\n:: Install phase\n"
    }

    ${commands [
      "mkdir -p \${out}/bin"
      "cp -v sh \${out}/bin/sh"
    ]}

  '';

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
