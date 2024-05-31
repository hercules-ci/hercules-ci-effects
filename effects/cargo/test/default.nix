{ pkgs }:
let
  effects = import ../../default.nix effects pkgs;
  inherit (effects) cargoPublish;
in
cargoPublish {
  src = ./.;
  secretName = "cargo-api-token";
  extraPublishArgs = [ "--dry-run" ];
}
