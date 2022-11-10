{ lib, pkgs, extraModule, ... }:
let
  inherit (lib) isFunction mapAttrsToList;

  nixos-lib = import (pkgs.path + "/nixos/lib") { inherit lib; };

in

module: nixos-lib.runTest {
  imports = [ ./effects-module.nix module extraModule ];
  config = {
    hostPkgs = pkgs;
  };
}
