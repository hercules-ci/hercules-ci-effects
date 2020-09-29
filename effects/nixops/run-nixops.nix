{ gnused, lib, mkEffect, nix, nixops, path, system }:

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

  # Override the Hercules CI State name if so desired. The default should
  # suffice.
  stateName ? "nixops-${name}.json",

  # Specify which secrets are to be loaded into the Effect sandbox.
  # For example { aws = "${env}-aws"; } will make the production-aws secret
  # available when env is "production"
  secretsMap ? {},

  # How to look up <nixpkgs> and other locations using that syntax.
  # Defaults to pkgs.path
  NIX_PATH ? "nixpkgs=${path}",

  # Other variables are passed to mkEffect, which is similar to mkDerivation.
  ...
}:
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
  inputs = [ nix nixops ];

  # Like `args // `, but also sets the defaults
  inherit networkFiles stateName NIX_PATH;

  getStateScript = ''
    stateFileName="$PWD/nixops-state.json"
    getStateFile "$stateName" "$stateFileName"
  '';

  postGetState = ''
    if test -f $stateFileName; then
      echo "importing state"
      nixops import \
        -d $stateName \
        --include-keys \
        <$stateFileName
      nixops modify -d $stateName $networkFiles
    else
      echo "creating new deployment state"
      nixops create -d $stateName $networkFiles
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
      -d $stateName \
      --confirm \
      --allow-reboot \
      --allow-recreate \
  '';

  prePutState = ''
    nixops export -d $stateName >$stateFileName
  '';

  putStateScript = ''
    putStateFile "$stateName" "$stateFileName"
  '';

  # We assume that `check` is idempotent and not required for any other operations.
  # To quote the NixOps help:
  #   check the state of the machines in the network (note that this might alter
  #   the internal nixops state to consolidate with the real state of the resource)
  effectCheckScript = ''
    nixops check -d "$stateName"
  '';

  priorCheckScript = ''
    nixops check -d "$stateName"
  '';

})
