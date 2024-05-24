{ pkgs }:
let
  effects = import ../../default.nix effects pkgs;
  inherit (effects) cargoPublish;
in
cargoPublish {
  secretName = "cargo-api-token";
}
