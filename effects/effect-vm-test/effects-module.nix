test@
{ config
, lib
, pkgs
, ...
}:
# pkgs, hci, runtimeShell, writeScriptBin, writeTextFile, writeText, runCommand, writeReferencesToFile }:
let
  inherit (lib) isFunction mapAttrsToList mkOption types;

  nixos-lib = import (pkgs.path + "/nixos/lib") { inherit lib; };

  # TODO: remove when next hci release is in Nixpkgs
  hci =
    let flake = builtins.getFlake "git+https://github.com/hercules-ci/hercules-ci-agent?ref=master&rev=6e298a833dc5321f7f9ff25bc243e4d7c65d928d";
    in flake.packages.x86_64-linux.hercules-ci-cli;

  wrapEffect = name: effect:
    let
      eff = effect.overrideAttrs (o: {
        # Work around Nix bug with unsafeDiscardOutputDependency, probably in libstore.
        makeNixSandboxBuildSucceed = true;
      });
    in
    pkgs.writeScriptBin "effect-${name}" ''
      #!${pkgs.runtimeShell}
      # retaining deps: ${eff.inputDerivation}
      hci effect run --no-token --project testforge/testorg/testrepo --as-branch main ${eff.drvPath}
    '';

  /*
    Return a store path with a closure containing everything including
    derivations and all build dependency outputs, all the way down.
  */
  allDrvOutputs = pkg:
    let name = "allDrvOutputs-${pkg.pname or pkg.name or "unknown"}";
    in
    pkgs.runCommand name { refs = pkgs.writeReferencesToFile pkg.drvPath; } ''
      touch $out
      while read ref; do
        case $ref in
          *.drv)
            cat $ref >>$out
            ;;
        esac
      done <$refs
    '';

  secrets2 = lib.mapAttrs
    (k: v:
      lib.throwIfNot (v?data) "secret `${k}` does not have a `data` attribute in test `${config.name}`" (
        { kind = "Secret"; condition = { and = [ ]; }; } // v
      )
    )
    config.secrets;
  secretsFile = pkgs.writeText "fake-secrets-${config.name}" (builtins.toJSON secrets2);

in
{
  options = {
    effects = mkOption {
      description = ''
        An attribute set of effects.

        The attribute name (referred to as `<name>`) translates to a command that is runnable from the {option}`testScript` as

        ```python
            agent.succeed("effect-<name>")
        ```
      '';
      type = types.lazyAttrsOf types.package;
    };

    secrets = mkOption {
      description = ''
        A collection of secrets available on the mock agent.
      '';
      type = types.lazyAttrsOf (types.lazyAttrsOf types.raw);
    };
  };

  config = {
    nodes.agent = {
      environment.systemPackages = [ hci ] ++ mapAttrsToList wrapEffect test.config.effects;
      # Might actually want to use `hci secret add` instead?
      # That will support dynamic secrets, like a host key that's
      # generated on the host.
      environment.variables.HERCULES_CI_SECRETS_JSON = "${secretsFile}";
    };
  };
}
