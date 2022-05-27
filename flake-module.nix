{ config, lib, flake-parts-lib, self, getSystem, ... }:
let
  inherit (lib)
    mkOption
    types
    ;
  inherit (flake-parts-lib)
    mkPerSystemOption
    ;
in
{
  _file = ./flake-module.nix;
  options = {
    perSystem = mkPerSystemOption ({ config, pkgs, ... }: {
      _file = ./flake-module.nix;
      options = {
        herculesCIEffects.pkgs = mkOption {
          type = types.raw or types.unspecified;
          description = ''
            Nixpkgs instance to use for hercules-ci-effects.
          '';
          default = pkgs;
          defaultText = "pkgs  # the module argument";
        };
      };
      config = {
        _module.args.effects =
          let effects = import ./effects/default.nix effects config.herculesCIEffects.pkgs;
          in effects;
      };
    });
  };
}
