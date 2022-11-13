toplevel@{ config, lib, flake-parts-lib, getSystem, ... }:
let
  inherit (lib) types mkOption;

  toplevelModules = rec {

    herculesCIModule = { config, ... }: {
      _file = ./perSystem-effects.nix;
      options = {
        onSchedule = mkOption {
          type = types.lazyAttrsOf (types.submoduleWith { modules = [ (herculesCIOnScheduleModule config) ]; });
        };
        onPush = mkOption {
          type = types.lazyAttrsOf (types.submoduleWith { modules = [ (herculesCIOnPushModule config) ]; });
        };
      };
    };

    herculesCIOnScheduleModule = herculesCI: { config, ... }: {
      options = {
        effects = mkOption {
          type = types.attrsOf (types.submodule effectSelectModule);
        };
      };
      config = {
        outputs.effects = lib.mapAttrs
          (selectName: selectConf:
            if selectConf.enable
            then (((getSystem toplevel.config.defaultEffectSystem).herculesCI herculesCI).onSchedule { /* onSchedule args */ }).effects.${selectName}
            else { }
          )
          config.effects;
      };
    };

    herculesCIOnPushModule = herculesCI: { config, ... }: {
      options = {
        effects = mkOption {
          type = types.attrsOf (types.submodule effectSelectModule);
        };
      };
      config = {
        outputs.effects = lib.mapAttrs
          (selectName: selectConf:
            if selectConf.enable
            then (((getSystem toplevel.config.defaultEffectSystem).herculesCI herculesCI).onPush { /* onPush args */ }).effects.${selectName}
            else { }
          )
          config.effects;
      };
    };

    effectSelectModule = { config, ... }: {
      options = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Whether to enable the effect for the [`defaultEffectSystem`](#opt-defaultEffectSystem).
          '';
        };
        # enableAllSystems = mkOption {
        #   description = ''
        #     Whether to enable the effect for all [`ciSystems`](#opt-herculesCI.ciSystems).
        #   '';
        # };
      };
    };
  };

  perSystemModules = rec {

    perSystemModule = { config, system, ... }: {
      _file = ./perSystem-effects.nix;
      options = {
        herculesCI = mkOption {
          type = types.deferredModuleWith { staticModules = [ herculesCIModule ]; };
          apply = module: herculesCI:
            let prefix = [ "perSystem" system "herculesCI" ]; in
            (lib.evalModules {
              modules = [
                module
                { config.repo = herculesCI.repo; }
              ];
              inherit prefix;
              specialArgs = { inherit prefix; };
            }).config;
        };
      };
    };

    herculesCIModule = { prefix, ... }: {
      options = {
        repo = lib.mkOption {
          type = types.raw;
          description = "See [herculesCI.repo](#opt-herculesCI.repo)";
          readOnly = true;
        };
        onPush = mkOption {
          type = types.deferredModuleWith { staticModules = [ handler ]; };
          apply = module: onPushArgs:
            (lib.evalModules {
              modules = [
                module
              ];
              prefix = prefix ++ [ "onPush" ];
              specialArgs = { };
            }).config;
        };
        onSchedule = mkOption {
          type = types.deferredModuleWith { staticModules = [ handler ]; };
          apply = module: onScheduleArgs:
            (lib.evalModules {
              modules = [
                module
              ];
              prefix = prefix ++ [ "onSchedule" ];
              specialArgs = { };
            }).config;
        };
      };
    };

    handler = { ... }: {
      options = {
        effects = lib.mkOption {
          type = types.lazyAttrsOf types.raw;
        };
      };
    };

  };


in
{
  options = {
    perSystem = flake-parts-lib.mkPerSystemOption perSystemModules.perSystemModule;
    herculesCI = mkOption {
      type = types.deferredModuleWith {
        staticModules = [ toplevelModules.herculesCIModule ];
      };
    };
    config = {
      herculesCI = { };
    };
  };
}
