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
  options = {
    perSystem = mkPerSystemOption ({ config, pkgs, ... }: {
      _file = ./flake-module.nix;
      options = {
        herculesCIEffects.pkgs = mkOption {
          type = types.raw or types.unspecified;
          description = ''
            Nixpkgs instance to use for <literal>hercules-ci-effects</literal>.

            The effects functions, etc, will be provided as the <literal>effects</literal> module argument of <literal>perSystem</literal>.
          '';
          default = pkgs;
          defaultText = lib.literalDocBook "<literal>pkgs</literal> (module argument)";
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
