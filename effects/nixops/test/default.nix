{ pkgs, lib }:
let
  effects = import ../../default.nix effects pkgs;
in
lib.recurseIntoAttrs {
  inherit (effects.runNixOps {
    src = ./.; # use cleanSourceWith!
    name = "deployment";
    networkFiles = [ "network.nix" ];
    prebuildOnlyNetworkFiles = [ "stub.nix" ];
  }) prebuilt;
}
