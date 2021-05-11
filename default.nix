/*
  To import, use

    let
      inherit (import effectsSrc { inherit pkgs; }) effects;
    in
      ...
 */

{ pkgs }: rec {
  effects = import ./effects/default.nix effects pkgs;
}
