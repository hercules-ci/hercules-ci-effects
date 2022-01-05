depArgs@
{ lib
, mkEffect
, writeText
, cachix
}:
let
  inherit (lib) optionalAttrs isAttrs;
in
args@{ deploy ? throw "effects.runCachixDeploy: you must provide either a deploy or deployJsonFile argument."
, deployJsonFile ? writeText "cachix-deploy.json" (builtins.toJSON deploy)
, cachix ? depArgs.cachix
, ...
}:
let
  checked =
    if args?deploy && args?deployJsonFile
    then throw "effects.runCachixDeploy: you must set either `deploy` or `deployJsonFile`."
    else x: x;
in
checked (mkEffect (removeAttrs args [ "deploy" "cachix" ] // {
  name = "cachix-deploy-effect";
  inputs = [
    cachix
  ] ++ args.inputs or [ ];
  userSetupScript = ''
    export CACHIX_ACTIVATE_TOKEN="$(readSecretString activate .cachixActivateToken)"
  '';
  effectScript = args.effectScript or ''
    cachix deploy activate ${deployJsonFile}
  '';
  secretsMap = { activate = "default-cachix-activate"; } // args.secretsMap or { };
  passthru =
    {
      inherit cachix;
      prebuilt = deployJsonFile;
    }
    // builtins.intersectAttrs { deploy = null; } args
    // args.passthru or { };
  dontUnpack = args.dontUnpack or true;
}))
