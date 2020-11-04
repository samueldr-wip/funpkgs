let
  inherit (import ./support {
    system = builtins.currentSystem;
  })
  runExecline
  externalSrc
  tinycc
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

  netbsd = {
    # This is make built from scratch, without a "boot" make.
    # Inspired by Makefile.boot
    boot.make =
      let
        SRCS = [
          # OBJ
          "arch.c"
          "buf.c"
          "compat.c"
          "cond.c"
          "dir.c"
          "for.c"
          "hash.c"
          "job.c"
          "main.c"
          "make.c"
          "make_malloc.c"
          "metachar.c" # Was missing from Makefile.boot
          "parse.c"
          "str.c"
          "strlist.c"
          "suff.c"
          "targ.c"
          "trace.c"
          "var.c"
          "util.c"

          # LIBOBJ
          "lst.lib/lstAppend.c"
          "lst.lib/lstAtEnd.c"
          "lst.lib/lstAtFront.c"
          "lst.lib/lstClose.c"
          "lst.lib/lstConcat.c"
          "lst.lib/lstDatum.c"
          "lst.lib/lstDeQueue.c"
          "lst.lib/lstDestroy.c"
          "lst.lib/lstDupl.c"
          "lst.lib/lstEnQueue.c"
          "lst.lib/lstFind.c"
          "lst.lib/lstFindFrom.c"
          "lst.lib/lstFirst.c"
          "lst.lib/lstForEach.c"
          "lst.lib/lstForEachFrom.c"
          "lst.lib/lstInit.c"
          "lst.lib/lstInsert.c"
          "lst.lib/lstIsAtEnd.c"
          "lst.lib/lstIsEmpty.c"
          "lst.lib/lstLast.c"
          "lst.lib/lstMember.c"
          "lst.lib/lstNext.c"
          "lst.lib/lstOpen.c"
          "lst.lib/lstRemove.c"
          "lst.lib/lstReplace.c"
          "lst.lib/lstSucc.c"
          "lst.lib/lstPrev.c"
        ];
      in
    runExecline "netbsd-make.boot-9.0" rec {
      version = "9.0";
      src = externalSrc.netbsd.${version}.make;
      mksys = externalSrc.netbsd.${version}.mk;
      CC = "${tinycc}/bin/tcc";
    } ''
      importas out out
      importas src src
      importas CC CC
      importas mksys mksys

      foreground {
        printf "\n:: Source phase\n"
      }

      foreground {
        cp -vr ''${src}/usr.bin/make /build
      }

      execline-cd make

      foreground {
        printf "\n:: Build phase\n"
      }

      ${commands (builtins.map (src:
      ''
        $CC -g -c ${src}
        -D_PATH_DEFSYSPATH=\"''${out}/share/mk\"
        -D_PATH_DEFSHELLDIR=\"${heirloom-sh}/bin/\"
      ''
      ) SRCS)}

      foreground {
        printf "\n:: Link phase\n"
      }

      backtick -i OBJS {
        find -name *.o -printf "%p "
      }

      importas -u -sd" " OBJS OBJS

      ${commands  [
        "$CC $OBJS -o make"
        "mkdir -p \${out}/bin"
        "mv -v make \${out}/bin/make"
      ]}

      foreground {
        printf "\n:: Misc. environment phase\n"
      }

      ${commands  [
        "mkdir -p \${out}/share/"
        # These are probably inappropriate in many ways.
        # Though sys.mk *is* needed.
        "cp -vr \${mksys}/share/mk \${out}/share/mk"
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

    foreground {
      cp -vr ''${src} /build/src
    }

    execline-cd src

    foreground {
      printf "\n:: Build phase\n"
    }

    ${commands [
      "$CC -c -D_GNU_SOURCE  -D_FILE_OFFSET_BITS=64L   args.c"
      "$CC -c -D_GNU_SOURCE  -D_FILE_OFFSET_BITS=64L   blok.c"
      "$CC -c -D_GNU_SOURCE  -D_FILE_OFFSET_BITS=64L   bltin.c"
      "$CC -c -D_GNU_SOURCE  -D_FILE_OFFSET_BITS=64L   cmd.c"
      "$CC -c -D_GNU_SOURCE  -D_FILE_OFFSET_BITS=64L   ctype.c"
      "$CC -c -D_GNU_SOURCE  -D_FILE_OFFSET_BITS=64L   defs.c"
      "$CC -c -D_GNU_SOURCE  -D_FILE_OFFSET_BITS=64L   echo.c"
      "$CC -c -D_GNU_SOURCE  -D_FILE_OFFSET_BITS=64L   error.c"
      "$CC -c -D_GNU_SOURCE  -D_FILE_OFFSET_BITS=64L   expand.c"
      "$CC -c -D_GNU_SOURCE  -D_FILE_OFFSET_BITS=64L   fault.c"
      "$CC -c -D_GNU_SOURCE  -D_FILE_OFFSET_BITS=64L   func.c"
      "$CC -c -D_GNU_SOURCE  -D_FILE_OFFSET_BITS=64L   hash.c"
      "$CC -c -D_GNU_SOURCE  -D_FILE_OFFSET_BITS=64L   hashserv.c"
      "$CC -c -D_GNU_SOURCE  -D_FILE_OFFSET_BITS=64L   io.c"
      "$CC -c -D_GNU_SOURCE  -D_FILE_OFFSET_BITS=64L   jobs.c"
      "$CC -c -D_GNU_SOURCE  -D_FILE_OFFSET_BITS=64L   macro.c"
      "$CC -c -D_GNU_SOURCE  -D_FILE_OFFSET_BITS=64L   main.c"
      "$CC -c -D_GNU_SOURCE  -D_FILE_OFFSET_BITS=64L   msg.c"
      "$CC -c -D_GNU_SOURCE  -D_FILE_OFFSET_BITS=64L   name.c"
      "$CC -c -D_GNU_SOURCE  -D_FILE_OFFSET_BITS=64L   print.c"
      "$CC -c -D_GNU_SOURCE  -D_FILE_OFFSET_BITS=64L   pwd.c"
      "$CC -c -D_GNU_SOURCE  -D_FILE_OFFSET_BITS=64L   service.c"
      "$CC -c -D_GNU_SOURCE  -D_FILE_OFFSET_BITS=64L   setbrk.c"
      "$CC -c -D_GNU_SOURCE  -D_FILE_OFFSET_BITS=64L   stak.c"
      "$CC -c -D_GNU_SOURCE  -D_FILE_OFFSET_BITS=64L   string.c"
      "$CC -c -D_GNU_SOURCE  -D_FILE_OFFSET_BITS=64L   test.c"
      "$CC -c -D_GNU_SOURCE  -D_FILE_OFFSET_BITS=64L   ulimit.c"
      "$CC -c -D_GNU_SOURCE  -D_FILE_OFFSET_BITS=64L   word.c"
      "$CC -c -D_GNU_SOURCE  -D_FILE_OFFSET_BITS=64L   xec.c"
      "$CC -c -D_GNU_SOURCE  -D_FILE_OFFSET_BITS=64L   gmatch.c"
      "$CC -c -D_GNU_SOURCE  -D_FILE_OFFSET_BITS=64L   getopt.c"
      "$CC -c -D_GNU_SOURCE  -D_FILE_OFFSET_BITS=64L   strsig.c"
      "$CC -c -D_GNU_SOURCE  -D_FILE_OFFSET_BITS=64L   version.c"
      "$CC -c -D_GNU_SOURCE  -D_FILE_OFFSET_BITS=64L   mapmalloc.c"
      "$CC -c -D_GNU_SOURCE  -D_FILE_OFFSET_BITS=64L   umask.c"
      "$CC  args.o blok.o bltin.o cmd.o ctype.o defs.o echo.o error.o expand.o fault.o func.o hash.o hashserv.o io.o jobs.o macro.o main.o msg.o name.o print.o pwd.o service.o setbrk.o stak.o string.o test.o ulimit.o word.o xec.o gmatch.o getopt.o strsig.o version.o mapmalloc.o umask.o  -o sh"
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
      "${netbsd.boot.make}/bin/make -f Makefile CC=tcc hello"
      "mkdir -p \${out}/bin"
      "cp -v hello \${out}/bin/hello"
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
      heirloom-sh
      netbsd
      test-make
      externalSrc
    ;
  }
