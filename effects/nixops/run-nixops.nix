{ gnused, lib, mkEffect, nix, nixops, path, system, git }:

let
  # This shouldn't be necessary after flakes.
  # We don't use this for the actual deployment.
  patchedNixOps = nixops.overrideAttrs (o: {
    name = "hercules-nixops-source";
    postPatch = ''
      ${o.postPatch or ""}
      ${gnused}/bin/sed -e 's!<nixpkgs\([^>]*\)>!${path}\1!g' -i $(find . -name "*\.nix")
    '';
    dontCheck = true;
  });

  prebuilt = args@{name, networkArgs, networkFiles, src}: let
      origSrc = src.origSrc or src;
      machineInfo = import "${patchedNixOps}/share/nix/nixops/eval-machine-info.nix" {
        inherit system;
        networkExprs = map (v: origSrc + "/${v}") networkFiles ++ [ ./dummy-network.nix ];
        uuid = "00000000-0000-0000-0000-000000000000";
        deploymentName = name;
        args = networkArgs;
      };
    in
      machineInfo.machines { names = lib.attrNames machineInfo.nodes; } // {
        inherit machineInfo;
        inherit (machineInfo) network nodes;
      };

  # Turn a value into a string that evaluates to that value in the Nix language.
  # Not currently in normal form.
  toNixExpr = v: "builtins.fromJSON \"" + lib.replaceStrings ["\$" "\"" "\\"] ["\\\$" "\\\"" "\\\\"] (builtins.toJSON v) + "\"";
in

args@{

  # Name of the deployment
  name,

  # NixOps network expressions and other files required for the deployment
  src,

  # Which files in src are the NixOps networks?
  networkFiles ? ["network.nix"],

  # Nix values to pass as NixOps network arguments. Only serializable values are
  # supported. Support for functions could be added, but they'll have to be
  # passed as strings in Nix syntax.
  networkArgs ? {},

  # Whether to build the network during the Hercules CI build phase.
  # This is currently the easiest way to upload the deployment to a cache
  # before deployment.
  prebuild ? true,

  # Prebuild runs outside of NixOps, which means that some info may be missing.
  # Specify extra network expressions here to fill in the missing definitions.
  prebuildOnlyNetworkFiles ? [],

  # Network files that are only used when deploy, so not when prebuilding.
  deployOnlyNetworkFiles ? [],

  # Override the Hercules CI State name if so desired. The default should
  # suffice.
  stateName ? "nixops-${name}.json",

  # Not all NixOps backends currently maintain known_hosts.
  knownHostsName ? "nixops-${name}.known_hosts",

  # Specify which secrets are to be loaded into the Effect sandbox.
  # For example { aws = "${env}-aws"; } will make the production-aws secret
  # available when env is "production"
  secretsMap ? {},

  # How to look up <nixpkgs> and other locations using that syntax.
  # Defaults to pkgs.path
  NIX_PATH ? "nixpkgs=${path}",

  # specify an action for the deploy which are mutually exclusive,
  # options: switch, dry-run, plan, build, create, copy, dry-activate, test, boot
  action ? "switch",
  # Other variables are passed to mkEffect, which is similar to mkDerivation.
  ...
}:
let
  actionFlag = {
    switch = "";
    dry-run = "--dry-run";
    plan = "--plan-only";
    build = "--build-only";
    create = "--create-only";
    copy= "--copy-only";
    dry-activate = "--dry-activate";
    test = "--test";
    boot = "--boot";
  }."${action}";
  canModifyState = (action != "dry-run");
in
mkEffect (
    lib.filterAttrs (k: v: k != "networkArgs" && k != "prebuildOnlyNetworkFiles") args
    // lib.optionalAttrs prebuild {
        prebuilt = prebuilt { 
          inherit name networkArgs src;
          networkFiles = networkFiles ++ prebuildOnlyNetworkFiles;
        };
      }
    // {
  name = "nixops-${name}";
  inputs = [ nix nixops git ] ++ (args.inputs or []);

  # Like `args // `, but also sets the defaults
  inherit deployOnlyNetworkFiles networkFiles stateName knownHostsName NIX_PATH;
  NIXOPS_DEPLOYMENT = args.NIXOPS_DEPLOYMENT or name;

  getStateScript = ''
    stateFileName="$PWD/nixops-state.json"
    getStateFile "$stateName" "$stateFileName"
    mkdir -p ~/.ssh
    getStateFile "$knownHostsName" ~/.ssh/known_hosts
    touch ~/.ssh/known_hosts
  '';

  postGetState = ''
    if test -f $stateFileName; then
      echo "importing state"
      nixops import \
        --include-keys \
        <$stateFileName
      nixops modify $networkFiles $deployOnlyNetworkFiles
    else
      echo "creating new deployment state"
      nixops create $networkFiles $deployOnlyNetworkFiles
    fi
    nixops set-args ${
      let
        args = lib.concatLists
          (lib.mapAttrsToList (k: v: 
            ["--arg" k (toNixExpr v)]
          ) networkArgs);
      in
        lib.escapeShellArgs args
    }
  '';

  effectScript = ''
    echo -n "version: "
    nixops --version
    nixops deploy \
      --confirm \
      --allow-reboot \
      --allow-recreate \
      ${actionFlag} \
  '';

  prePutState = lib.optionalString canModifyState ''
    nixops export >"$stateFileName"
    if [[ ! -s "$stateFileName" ]]; then
      echo 1>&2 "NixOps state export was empty. Upload cancelled."
      rm "$stateFileName"
      exit 1
    fi
  '';

  putStateScript = lib.optionalString canModifyState ''
    putStateFile "$stateName" "$stateFileName"
    putStateFile "$knownHostsName" ~/.ssh/known_hosts
  '';

  # We assume that `check` is idempotent and not required for any other operations.
  # To quote the NixOps help:
  #   check the state of the machines in the network (note that this might alter
  #   the internal nixops state to consolidate with the real state of the resource)
  effectCheckScript = args.effectCheckScript or (lib.optionalString canModifyState ''
    nixops check
  '');

  priorCheckScript = args.priorCheckScript or (''
    nixops check
  '');

})
