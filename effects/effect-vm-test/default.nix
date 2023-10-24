{ lib, pkgs, extraModule, ... }:
let
  inherit (lib) isFunction mapAttrsToList;

  nixos-lib = import (pkgs.path + "/nixos/lib") { inherit lib; };

in

module: nixos-lib.runTest {
  imports = [ ./optimize.nix ./effects-module.nix module extraModule ];
  config = {
    node.pkgs = lib.mkDefault pkgs;
    hostPkgs = pkgs;
  };
}
