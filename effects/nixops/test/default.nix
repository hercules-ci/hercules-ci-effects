{ pkgs, lib }:
let
  effects = import ../../default.nix effects pkgs;
in
effects.runNixOps {
  src = ./.; # use cleanSourceWith!
  name = "deployment";
  networkFiles = [ "network.nix" ];
  prebuildOnlyNetworkFiles = [ "stub.nix" ];
  action = "dry-run";
}
