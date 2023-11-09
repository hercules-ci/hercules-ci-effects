{ config, lib, flake-parts-lib, self, getSystem, inputs, ... }:
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
    perSystem = mkPerSystemOption ({ config, options, pkgs, ... }:
    let
      hci-effects = checkVersion import ../effects/default.nix hci-effects config.herculesCIEffects.pkgs;

      checkVersion = import ../effects/lib-version-check.nix {
        inherit (config.herculesCIEffects.pkgs) lib;
        revInfo =
          # pkgs doesn't carry its own revision, so we guess where it came from and report if we got it right.
          if toString pkgs.path == toString inputs.nixpkgs.outPath or null
              && inputs?nixpkgs.rev
          then " (rev: ${inputs.nixpkgs.rev})"
          else "";
        versionSource = if options.herculesCIEffects.pkgs.highestPrio < (lib.mkOptionDefault {}).priority
          then "from the perSystem option `herculesCIEffects.pkgs`"
          else "from the perSystem `pkgs` module argument";
        component = "hercules-ci-effects.flakeModule";
      };
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
