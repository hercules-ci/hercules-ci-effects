test@
{ config
, lib
, pkgs
, ...
}:
# pkgs, hci, runtimeShell, writeScriptBin, writeTextFile, writeText, runCommand, writeReferencesToFile }:
let
  inherit (lib)
    isFunction
    mapAttrs
    mapAttrsToList
    mkOption
    types;

  nixos-lib = import (pkgs.path + "/nixos/lib") { inherit lib; };

  # Convert a mkDerivation package to a derivation JSON object (approximately)
  # Reconstruct the builtins.derivation behavior from mkDerivation internal noise
  # WARNING: very broken, basically untested
  derivationObject =
    let
      stringifiers = {
        "string" = x: x;
        "int" = x: toString x;
        "bool" = x: if x then "1" else "";
        "path" = x: "${x}";
        "list" = x: lib.concatStringsSep " " (map stringify x);
        "set" = x: "${x}";
      };
      stringify = x: stringifiers.${builtins.typeOf x} x;

      drvOutput = o:
        # { outputs = o.outputs; dynamicOutputs = []; };
        o.outputs;

      ctxToDrv = k: v:
        if v?outputs then { "${k}" = drvOutput v; }
        else { };

      ctxToSrc = k: v:
        if v.path or false then ["${k}"]
        else [ ];

    in
    drvPackage:
    let
      env =
        mapAttrs
          (k: v:
            builtins.addErrorContext
              "while evaluating derivation attribute ${k}"
              (stringify v))
          (lib.filterAttrs
            (k: v:
              builtins.addErrorContext
                "while evaluating derivation attribute ${k}" (v != null))
                drvPackage.drvAttrs);

      beforeInputs = {
        args = drvPackage.args;
        builder = drvPackage.builder;
        env = env;
        name = drvPackage.name;
        outputs = { "out" = {}; };
        system = drvPackage.system;
      };
      context = builtins.getContext (builtins.toJSON beforeInputs);
      inputDrvs = lib.concatMapAttrs ctxToDrv context;
      inputSrcs = lib.concatLists (lib.mapAttrsToList ctxToSrc context);
    in
      beforeInputs // {
        inherit inputDrvs inputSrcs;
      };

  # Produce a derivation ATerm without dependencies or outputs
  unsafeToATerm = pkg:
    let o = derivationObject pkg;
      outPath = "/nix/store/00000000000000000000000000000000-effect-vm-test-fake-output";
      outputs = ''[("out",${escape outPath},"","")]'';
      inputDrvs = "[]";
      inputSrcs = "[]";
      escape = builtins.toJSON; # good enough??
      system = escape o.system;
      builder = escape o.builder;
      args = escape o.args;
      env = "["
        + lib.concatStringsSep "," (lib.mapAttrsToList (k: v: "(${escape k},${escape v})") (o.env // { "out" = outPath; }))
        + "]";
    in
      "Derive(${outputs},${inputDrvs},${inputSrcs},${system},${builder},${args},${env})";

  # derivationJSON = pkg: builtins.toJSON (derivationObject pkg);

  wrapEffect = name: effect:
    # TODO: use unsafeDiscardOutputDependency blocked on https://github.com/NixOS/nix/issues/9146
    #       or use a different workaround that doesn't depend on build closure's outputs all the way to bootstrap
    #
    # For now we write a fake derivation, and rely on the whole storeDir to be forwarded by hci effect run.
    pkgs.writeScriptBin "effect-${name}" ''
      #!${pkgs.runtimeShell}
      drv=${pkgs.writeText "effect-${name}-drv" (unsafeToATerm effect)}
      hci effect run --no-token --project testforge/testorg/testrepo --as-branch main $drv
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
    hci = mkOption {
      type = types.package;
      description = ''
        Hercules CI CLI package to use in the test runner.
      '';
    };
    effects = mkOption {
      description = ''
        An attribute set of effects.

        The attribute name (referred to as `<name>`) translates to a command that is runnable from the `testScript` as

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
      default = {};
    };
  };

  config = {
    nodes.agent = {
      environment.systemPackages = [ config.hci ] ++ mapAttrsToList wrapEffect test.config.effects;
      # Might actually want to use `hci secret add` instead?
      # That will support dynamic secrets, like a host key that's
      # generated on the host.
      environment.variables.HERCULES_CI_SECRETS_JSON = "${secretsFile}";
    };
  };
}
