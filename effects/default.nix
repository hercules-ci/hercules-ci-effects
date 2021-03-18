# The resulting attribute set. E.g. let effects = import ./default.nix effects pkgs
self:

# Nixpkgs
pkgs:

let
  inherit (pkgs) callPackage;
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

  runArion = callPackage ./arion/run-arion.nix { inherit (self) mkEffect; };

  runNixDarwin = callPackage ./nix-darwin/run-nix-darwin.nix { inherit (self) mkEffect; };

  runNixOps = callPackage ./nixops/run-nixops.nix { inherit (self) mkEffect; };

  runNixOS = callPackage ./nixos/run-nixos.nix { inherit (self) mkEffect; };

  # A simple example
  runPutUrl = callPackage ./run-put-url.nix { inherit (self) mkEffect; };

  git-crypt-hook = callPackage ./git-crypt-hook/default.nix { };

}
