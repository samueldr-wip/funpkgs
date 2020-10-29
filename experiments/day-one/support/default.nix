{ system }:

let
  # We're not self-bootstrapping yet.
  # For now we use *external* tools.
  # Don't look behind the curtain.
  external = import ./external.nix;

  inherit (external)
    # execline is used for scripting and commands-chaining
    execlineb execline
    # a simple C compiler
    tinycc
    # toybox provides us with utilities
    toybox
  ;

  runExecline = name: {PATH ? "", ...}@args: script: derivation (args // {
    inherit name;
    inherit system;

    builder = execlineb;
    args = [ "-c" script];

    PATH = "${PATH}:${execline}/bin:${toybox}/bin";
  });

  writeTextFile = {
    name,
    text,
    destination ? "",
    checkPhase ? "",
    executable ? false
  }:
    runExecline name {
    inherit text;
    passAsFile = [
      "text"
    ];
  } ''
    importas out out
    importas textPath textPath
    foreground { cp $textPath $out${destination} }
    ${if executable then "foreground { chmod +x $textPath $out${destination} }" else ""}
    foreground { ${checkPhase} }
  '';

  writeText = name: text: writeTextFile {
    inherit name text;
  };
  writeScript = name: text: writeTextFile {
    inherit name text;
    executable = true;
  };

  # Useful?
  compileCFile = name: file: runExecline name { inherit file; } ''
    importas out out
    importas file file
    foreground {
      echo ":: Compiling single C source code file: $file"
    }
    foreground {
      ${tinycc}/bin/tcc ${file} -o $out
    }
  '';
in
  {
    inherit
      compileCFile
      runExecline
      writeScript
      writeText
    ;
  }
