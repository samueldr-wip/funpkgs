`Funpkgs`?
==========

*Nothing really to see here. It **really** is only a playground for trying
stuff out. Don't expect anything here.*

* * *

You probably want to `nix-shell` before using `nix-build` or `nix build`, to
ensure no default sandbox impurities.

Sandbox impurities??
--------------------

We are wrapping nix and nix-build in `shell.nix`.

The goal of that minimal wrapper is to completely opt-out any and all sandbox
paths that may exist with default Nix configurations.

Building with the default sandbox settings *could* result in different results.

`Funpkgs` does not aim to be POSIX compliant with regards to `/bin/sh` during
builds.
