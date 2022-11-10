flakeParts@{ lib, config, self, ... }:
let
  inherit (lib)
    types
    mkOption
    ;

  herculesCIModule = { config, ... }: {
    config = {
      out = {
        _debug = config;
      };
    };
  };

in
{

  options = {
    herculesCI = mkOption {
      type = types.deferredModuleWith { staticModules = [ herculesCIModule ]; };
    };

    defaultEffectSystem = mkOption {
      type = types.str;
      default = "x86_64-linux";
      description = ''
        The default system type that some integrations will use to run their effects on.
      '';
    };
  };

}