# The resulting attribute set. E.g. let effects = import ./default.nix effects pkgs
self:

# Nixpkgs
pkgs:

let
  inherit (pkgs) callPackage;

in {
  mkEffect = callPackage ./effect/effect.nix { };

  runArion = callPackage ./arion/run-arion.nix { inherit (self) mkEffect; };

  runNixDarwin = callPackage ./nix-darwin/run-nix-darwin.nix { inherit (self) mkEffect; };

  runNixOps = callPackage ./nixops/run-nixops.nix { inherit (self) mkEffect; };

  runNixOps2 = callPackage ./nixops2/run-nixops.nix { inherit (self) mkEffect; };

  # A simple example
  runPutUrl = callPackage ./run-put-url.nix { inherit (self) mkEffect; };

}
