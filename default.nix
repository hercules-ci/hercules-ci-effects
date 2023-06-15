/*
  To import, use

    let
      inherit (import effectsSrc { inherit pkgs; }) effects;
    in
      ...
 */

{ pkgs }: rec {
  effects = hci-effects;
  hci-effects = import ./effects/default.nix effects pkgs;
  modules = import ./effects/modules.nix;
}
