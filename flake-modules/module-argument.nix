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
    perSystem = mkPerSystemOption ({ config, pkgs, ... }:
    let
      hci-effects = import ../effects/default.nix hci-effects config.herculesCIEffects.pkgs;
    in
    {
      _file = ./module-argument.nix;
      options = {
        herculesCIEffects.pkgs = mkOption {
          type = types.raw or types.unspecified;
          description = ''
            Nixpkgs instance to use for `hercules-ci-effects`.

            The effects functions, etc, will be provided as the `effects` module argument of `perSystem`.
          '';
          default = pkgs;
          defaultText = lib.literalMD "`pkgs` (module argument)";
        };
      };
      config = {
        _module.args.effects = lib.warn "The effects module argument has been renamed to hci-effects." hci-effects;
        _module.args.hci-effects = hci-effects;
      };
    });
  };
}
