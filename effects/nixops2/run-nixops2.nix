packageArgs@{ gnused, lib, mkEffect, nix, nixopsUnstable, path, system, runCommand, openssh, rsync, hci, git }:

let
  inherit (lib)
    escapeShellArgs optionals;

  # We don't use this for the actual deployment.
  getNixFiles = nixops: runCommand "${nixops.name}-nix-files" {
    plugins =
      if lib.isList nixops.plugins
      then nixops.plugins
      else lib.attrValues nixops.plugins;
    inherit nixops;
  } ''
    mkdir $out
    echo "[" >$out/all-plugins.nix
    notnull() {
      [[ $# > 0 ]]
    }
    for plugin in $plugins $nixops; do
      # NixOps itself
      if notnull $plugin/lib/python*/site-packages/nix; then
        echo "copying nixops nix exprs from $plugin"
        cp --no-preserve=mode -r $plugin/lib/python*/site-packages/nix/* $out
      elif notnull $plugin/lib/python*/site-packages/*/nix/default.nix; then

        defaultNix="$(echo $plugin/lib/python*/site-packages/*/nix/default.nix)"
        if grep -E '../../auto-raid' $defaultNix; then
          # nixos-modules-contrib has upreferences, and we can't just copy it
          # but it appears to be imported transitively anyway.
          :
        else
          name=$(basename $(dirname $(dirname $defaultNix)))
          cp --no-preserve=mode -r $plugin/lib/python*/site-packages/$name/nix $out/$name
          echo "  ./$name" >>$out/all-plugins.nix
        fi
      else
        echo "warning: don't know how to gather Nix expressions from plugin $plugin. Does it have Nix expressions?"
      fi
    done
    echo "]" >>$out/all-plugins.nix

    # Fixup NIX_PATH use
    sed -e 's^<nixops\([^>]*\)>^'$out'\1^g' -i $(find $out -type f -name "*\.nix")
    sed -e 's^<nixpkgs\([^>]*\)>^${path}\1^g' -i $(find $out -type f -name "*\.nix")

    (cd $out; patch --strip 2 <${./nixops.diff}) || {
      echo >&2 "Ignoring failed patch"
      echo >&2 "Assuming nixops is new enough"
    }

  '';

  prebuilt = {
    name,
    prebuildNetworkArgs,
    flake,
    nixops,
    src,
    networkFiles,
    prebuildOnlyNetworkFiles,
    prebuildOnlyModules,
    forgetState,
  }: let
    nixFiles = getNixFiles nixops;
    origSrc = src.origSrc or src;
    machineInfo = import "${nixFiles}/eval-machine-info.nix" ({
      inherit system;
      uuid = "00000000-0000-0000-0000-000000000000";
      deploymentName = name;
      args = prebuildNetworkArgs;
      pluginNixExprs = import "${nixFiles}/all-plugins.nix";
    } // (if flake == null then {
      networkExprs = [ ./prebuild-stub.nix ] ++ map (v: origSrc + "/${v}") (networkFiles ++ prebuildOnlyNetworkFiles) ++ prebuildOnlyModules;
    } else {
      networkExprs = [ ./prebuild-stub.nix ] ++ prebuildOnlyNetworkFiles ++ prebuildOnlyModules;
      flakeExpr = flake.nixopsConfigurations.default;
      flakeUri = flake.outPath;
    }));
    inherit (machineInfo) info;
    errorIf = c: e: if c then throw e else x: x;
    withChecks = if forgetState then x: x else withChecks';
    withChecks' = x:
      errorIf (! info?network.storage || info?network.storage.legacy)
        "Your deployment must specify a remote storage solution, such as network.storage.hercules-ci. If you know for sure that your deployment is stateless, pass forgetState = true to runNixOps2." (
        lib.warnIf
          (! info?network.lock || info.network.lock == {} || info?network.lock.noop)
          "Your deployment does not specify remote lock driver, such as network.lock.hercules-ci. Concurrent use will result in lost state, misconfigured and/or redundant cloud resources and unexpectedly high expenses."
          x
        );
  in withChecks (
    machineInfo.machines { names = lib.attrNames machineInfo.nodes; } // {
      inherit machineInfo;
      inherit (machineInfo) network nodes;
    }
  );

in

# Docs: runNixOps2.adoc
args@{
  name ? null,
  flake ? null,
  src ? flake.outPath,
  forgetState ? false,
  prebuildNetworkArgs ? {},
  secretsMap ? {},
  nixops ? nixopsUnstable,
  nix ? packageArgs.nix,
  prebuild ? true,
  prebuildOnlyNetworkFiles ? [],
  prebuildOnlyModules ? [],
  networkFiles ? null,
  action ? "switch",
  allowReboot ? true,
  allowRecreate ? true,
  extraDeployArgs ? [],
  ...
}:
let
  actionFlag = {
    switch = [];
    dry-run = ["--dry-run"];
    plan = ["--plan-only"];
    build = ["--build-only"];
    create = ["--create-only"];
    copy = ["--copy-only"];
    dry-activate = ["--dry-activate"];
    test = ["--test"];
    boot = ["--boot"];
  }."${action}";

  deployArgs =
    actionFlag
    ++ optionals allowReboot ["--allow-reboot"]
    ++ optionals allowRecreate ["--allow-recreate"]
    ++ extraDeployArgs
    ;

  name2 = if name != null then name else "nixops";

  throwIfNot = c: msg: if !c then throw msg else x: x;

in
# Either flake or networkFiles must be set.
assert ((flake == null) != (networkFiles == null));

throwIfNot
  (action == "switch" || (args?makeAnException && args.makeAnException == "I know this can corrupt the state, until https://github.com/NixOS/nixops/issues/1499 is resolved."))
  "The runNixOps2 action parameter is disabled until https://github.com/NixOS/nixops/issues/1499 is resolved."

mkEffect (
  {
    NIX_PATH="nixpkgs=${path}";
  }
  // lib.filterAttrs (k: v: k != "prebuildNetworkArgs" && k != "prebuildOnlyModules" && k != "flake") args
    // lib.optionalAttrs prebuild {
        prebuilt = prebuilt { 
          inherit
            prebuildNetworkArgs
            flake
            nixops
            src
            networkFiles
            prebuildOnlyNetworkFiles
            prebuildOnlyModules
            forgetState;
          name = name2;
        };
      }
    // {
  name = "nixops-${name2}";
  inherit src;
  inputs = [
    nix nixops openssh rsync hci
    # dependency of nix
    git
  ] ++ (args.inputs or []);

  NIXOPS_DEPLOYMENT = args.NIXOPS_DEPLOYMENT or name;

  effectScript = args.effectScript or ''
    nixops deploy \
      --confirm \
      ${escapeShellArgs deployArgs} \
      ;
  '';

  # We assume that `check` is idempotent and not required for any other operations.
  # To quote the NixOps help:
  #   check the state of the machines in the network (note that this might alter
  #   the internal nixops state to consolidate with the real state of the resource)
  effectCheckScript = args.effectCheckScript or ''
    nixops check
  '';

  priorCheckScript = args.priorCheckScript or ''
    nixops check
  '';

})
