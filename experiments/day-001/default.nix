let
  inherit (import ./support {
    system = builtins.currentSystem;
  })
  compileCFile
  runExecline
  writeScript
  writeText
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

  test_execline = runExecline "funpkgs.bootstrap.stage-0" {
    inherit banner;
    passAsFile = [
      "banner"
    ];
  } ''
    importas out out
    importas bannerPath bannerPath
    foreground {
      cat $bannerPath
    }
    foreground {
      printf "stage-0 of Funpkgs\n\n"
    }
    foreground {
      mkdir -p $out
    }
    redirfd -w 1 ''${out}/success
    echo "This is working just fine! 👀 🎉"
  ''
  ;

  test_writeScript = writeScript "script.rb" ''
    puts "hi!!!"
  '';

  hello_c = writeText "hello.c" ''
    #include <stdio.h>
    int main() {
       printf("Hello, World!\n");
       return 0;
    }
  '';

  hello-world = compileCFile "hello-world" hello_c;
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
      test_execline
      test_writeScript
      hello-world
    ;
  }
