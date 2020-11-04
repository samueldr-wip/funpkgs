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
        ''$CC -g -c ${src} -D_PATH_DEFSYSPATH=\"''${out}/share/mk\"''
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
      netbsd
      externalSrc
    ;
  }
