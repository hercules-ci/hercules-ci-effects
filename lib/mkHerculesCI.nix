# Static arguments provided by flake-public-outputs.nix
hercules-ci-effects-inputs@{ flake-parts, ... }:

# User arguments
{ inputs }: module:
let
  flake =
    flake-parts.lib.mkFlake { inherit inputs; } ({ lib, config, self, ... }: {
      options = {
        selfAttributesDefinedViaMkHerculesCI = lib.mkOption {
          description = ''
            Flake output attributes that the `mkHerculesCI` caller
            assigns to the flake outputs, a.k.a. `self`.
                        
            These must be excluded from the `self` values that are
            assigned to the `flake` option and subsequent use in
            the `onPush.default` job.

            Usually, the default will suffice.
          '';
        };
      };
      imports = [
        hercules-ci-effects-inputs.self.flakeModule
        (lib.setDefaultModuleLocation "the mkHerculesCI argument" module)
      ];
      config = {
        systems = lib.mkDefault [ config.defaultEffectSystem ];
        # We're doing things the other way around...
        herculesCI.flakeForOnPushDefault = { outputs = config.flake; };

        # self.herculesCI is supposed to be defined by mkHerculesCI.
        # If we were to set it here, that would cause it to
        # recursively merge itself with itself, infinitely.
        selfAttributesDefinedViaMkHerculesCI = [ "herculesCI" ];

        flake =
          builtins.removeAttrs (self.outputs or self) config.selfAttributesDefinedViaMkHerculesCI;
      };
    });
in
flake.herculesCI
