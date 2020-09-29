# The resulting attribute set. E.g. let effects = import ./default.nix effects pkgs
self:

# Nixpkgs
pkgs:

let
  inherit (pkgs) callPackage;

in {
  mkEffect = callPackage ./effect/effect.nix { };

  # A simple example
  runPutUrl = callPackage ./run-put-url.nix { inherit (self) mkEffect; };

  runNixOps = callPackage ./nixops/run-nixops.nix { inherit (self) mkEffect; };

}
