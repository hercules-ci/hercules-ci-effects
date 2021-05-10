{ lib, nix }:

{ shell }: run:
  if ! lib.isDerivation shell
  then throw "effects.nix-shell: `shell` must be a derivation, but got ${builtins.typeOf shell}"
  else
    let
      inputs = shell.inputDerivation;
      unbuiltDrvPath = builtins.unsafeDiscardOutputDependency shell.drvPath;
    in
      lib.strings.addContextFrom inputs
        "${nix}/bin/nix-shell ${unbuiltDrvPath} --run ${lib.escapeShellArg run}"
