{ lib, nixosTest, hci, runtimeShell, writeScriptBin, writeTextFile, writeText, runCommand, writeReferencesToFile }:
let
  inherit (lib) isFunction mapAttrsToList;

  # TODO: remove when next hci release is in Nixpkgs
  hci =
    let flake = builtins.getFlake "git+https://github.com/hercules-ci/hercules-ci-agent?ref=master&rev=6e298a833dc5321f7f9ff25bc243e4d7c65d928d";
    in flake.packages.x86_64-linux.hercules-ci-cli;

  # TODO: use Nixpkgs lib.toFunction
  toFunction =
    # Any value
    v:
    if isFunction v
    then v
    else k: v;

  wrapEffect = name: effect:
    let
      eff = effect.overrideAttrs (o: {
        # Work around Nix bug with unsafeDiscardOutputDependency, probably in libstore.
        makeNixSandboxBuildSucceed = true;
      });
    in
    writeScriptBin "effect-${name}" ''
      #!${runtimeShell}
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
    runCommand name { refs = writeReferencesToFile pkg.drvPath; } ''
      touch $out
      while read ref; do
        case $ref in
          *.drv)
            cat $ref >>$out
            ;;
        esac
      done <$refs
    '';

in

{ name ? "unnamed", effects, nodes, secrets ? { }, testScript }:
let
  secrets2 = lib.mapAttrs
    (k: v:
      lib.throwIfNot (v?data) "secret `${k}` does not have a `data` attribute in test `${name}`" (
        { kind = "Secret"; condition = { and = [ ]; }; } // v
      )
    )
    secrets;
  secretsFile = writeText "fake-secrets-${name}" (builtins.toJSON secrets2);
in
nixosTest {
  name = "effect-${name}";
  nodes = nodes // {
    agent = {
      imports = [ nodes.agent or { } ];
      environment.systemPackages = [ hci ] ++ mapAttrsToList wrapEffect effects;
      # Might actually want to use `hci secret add` instead?
      # That will support dynamic secrets, like a host key that's
      # generated on the host.
      environment.variables.HERCULES_CI_SECRETS_JSON = "${secretsFile}";
    };
  };
  inherit testScript;
}
