nixpkgsArgs@{ gnused, lib, mkEffect, nix, path, system, runCommand }:

let
  # This shouldn't be necessary after flakes.
  # We don't use this for the actual deployment.
  getNixFiles = nixops: runCommand "${nixops.name}-nix-files" {
    inherit (nixops) plugins;
  } ''
    mkdir $out
    echo "[" >$out/all-plugins.nix
    notnull() {
      [[ $# > 0 ]]
    }
    for plugin in $plugins; do
      # NixOps itself
      if notnull $plugin/lib/python*/site-packages/nix; then
        echo "copying nixops nix exprs from $plugin"
        cp --no-preserve=mode -r $plugin/lib/python*/site-packages/nix/* $out
      elif notnull $plugin/lib/python*/site-packages/*/nix/default.nix; then
        defaultNix=$plugin/lib/python*/site-packages/*/nix/default.nix
        name=$(basename $(dirname $(dirname $defaultNix)))
        cp --no-preserve=mode -r $plugin/lib/python*/site-packages/$name/nix $out/$name
        echo "  ./$name" >>$out/all-plugins.nix
      else
        echo "don't know how to use $plugin"
        exit
      fi
        # echo "copying plugin nix exprs from $plugin"
        # Plugins usually define nix/default as the only `def nixexprs()`
        # cp $plugin/lib/python3.8/site-packages/*/nix/* $out
    done
    echo "]" >>$out/all-plugins.nix

    # Fixup NIX_PATH use
    sed -e 's^<nixops\([^>]*\)>^'$out'\1^g' -i $(find $out -type f -name "*\.nix")
    sed -e 's^<nixpkgs\([^>]*\)>^${path}\1^g' -i $(find $out -type f -name "*\.nix")

  '';

  prebuilt = args@{name, networkArgs, networkFiles, src, nixops}: let
      nixFiles = getNixFiles nixops;
      origSrc = src.origSrc or src;
      machineInfo = import "${nixFiles}/eval-machine-info.nix" {
        inherit system;
        networkExprs = map (v: origSrc + "/${v}") networkFiles ++ [ ./dummy-network.nix ];
        uuid = "00000000-0000-0000-0000-000000000000";
        deploymentName = name;
        args = networkArgs;
        pluginNixExprs = import "${nixFiles}/all-plugins.nix";
      };
    in
      machineInfo.machines { names = lib.attrNames machineInfo.nodes; };

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

  nixops,

  # Other variables are passed to mkEffect, which is similar to mkDerivation.
  ...
}:
mkEffect (
    lib.filterAttrs (k: v: k != "networkArgs" && k != "prebuildOnlyNetworkFiles") args
    // lib.optionalAttrs prebuild {
        prebuilt = prebuilt { 
          inherit name networkArgs src nixops;
          networkFiles = networkFiles ++ prebuildOnlyNetworkFiles;
        };
      }
    // {
  name = "nixops-${name}";
  inputs = [ nix nixops ];

  # Like `args // `, but also sets the defaults
  inherit deployOnlyNetworkFiles networkFiles stateName knownHostsName NIX_PATH;
  NIXOPS_DEPLOYMENT = args.NIXOPS_DEPLOYMENT or name;

  getStateScript = ''
    stateFileName="$PWD/nixops-state.json"
    getStateFile "$stateName" "$stateFileName"
    mkdir -p ~/.ssh
    getStateFile "$knownHostsName" ~/.ssh/known_hosts
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
  '';

  prePutState = ''
    nixops export >"$stateFileName"
    if [[ ! -s "$stateFileName" ]]; then
      echo 1>&2 "NixOps state export was empty. Upload cancelled."
      rm "$stateFileName"
      exit 1
    fi
  '';

  putStateScript = ''
    putStateFile "$stateName" "$stateFileName"
    putStateFile "$knownHostsName" ~/.ssh/known_hosts
  '';

  # We assume that `check` is idempotent and not required for any other operations.
  # To quote the NixOps help:
  #   check the state of the machines in the network (note that this might alter
  #   the internal nixops state to consolidate with the real state of the resource)
  effectCheckScript = ''
    nixops check
  '';

  priorCheckScript = ''
    nixops check
  '';

})
