# The resulting attribute set. See ../default.nix.
self:

# Nixpkgs
pkgs:

let
  callPackage = pkgs.newScope self;
  inherit (pkgs.lib) recurseIntoAttrs optionalAttrs;

in {
  mkEffect = callPackage ./effect/effect.nix { };

  runIf = condition: v:
    recurseIntoAttrs (
      (
        if condition
        then { run = v; }
        else { dependencies = v // { isEffect = false; buildDependenciesOnly = true; }; }
      ) // optionalAttrs (v ? prebuilt) {
        inherit (v) prebuilt;
      }
    );

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

}
