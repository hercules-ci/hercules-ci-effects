# The resulting attribute set. See ../default.nix.
self:

# Nixpkgs
pkgs:

let
  callPackage = pkgs.newScope self;
  inherit (pkgs.lib)
    recurseIntoAttrs
    optionalAttrs
    evalModules
    mkDefault
    ;

  evalEffectModules = { modules }: evalModules {
    modules = [
      ./effect/effect-module.nix
      {
        _file = __curPos.file;
        _module.args.pkgs = mkDefault pkgs;
      }
    ] ++ modules;
    specialArgs = {
      hci-effects = self;
    };
  };

in
{
  mkEffect = callPackage ./effect/effect.nix { };

  modularEffect = module: (evalEffectModules { modules = [ module ]; }).config.effectDerivation;

  runIf = condition: v:
    recurseIntoAttrs (
      (
        if condition
        then { run = v; }
        else { dependencies = v.inputDerivation // { isEffect = false; buildDependenciesOnly = true; }; }
      ) // optionalAttrs (v ? prebuilt) {
        inherit (v) prebuilt;
      }
    );

  flakeUpdate = callPackage ./flake-update/effect-fun.nix { };

  netlifyDeploy = callPackage ./netlify { };
  netlifySetupHook = pkgs.runCommand "hercules-ci-netlify-setup-hook" {} ''
    mkdir -p $out/nix-support
    cp ${./netlify/netlify-setup-hook.sh} $out/nix-support/setup-hook
  '';

  runArion = callPackage ./arion/run-arion.nix { };

  runCachixDeploy = callPackage ./cachix-deploy/run-cachix-deploy.nix { };

  runNixDarwin = callPackage ./nix-darwin/run-nix-darwin.nix { };

  runNixOps = callPackage ./nixops/run-nixops.nix { };

  runNixOps2 = callPackage ./nixops2/run-nixops2.nix { };

  runNixOS = callPackage ./nixos/run-nixos.nix { };

  # A simple example
  runPutUrl = callPackage ./run-put-url.nix { };

  git-crypt-hook = callPackage ./git-crypt-hook/default.nix { };

  nix-shell = callPackage ./nix-shell/default.nix { };

  ssh = callPackage ./ssh/call-ssh.nix { };

  effectVMTest = callPackage ./effect-vm-test { extraModule = { config.hci = pkgs.hci; }; };

  effects = self;

  inherit callPackage;
}
