{inputs, withSystem, ...}:
let
  attic-client = inputs.attic.packages."x86_64-linux".attic-client;
  cachix = withSystem "x86_64-linux" ({pkgs, ...}: pkgs.cachix);
  in
{
  inputs,
  lib,
  withSystem,
  config,
  ...
}: {
  imports = [
    inputs.hercules-ci-effects.flakeModule
  ];

  options = {
    populate-cache-effect = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enables HerculesCI effects populating some external cache.";
      };
      attic-client-pkg = lib.mkOption {
        type = lib.types.package;
        description = "Version of the attic-client package to use on \"x86_64-linux\".";
        default = attic-client;
      };
      cachix-pkg = lib.mkOption {
        type = lib.types.package;
        description = "Version of the cachix package to use on \"x86_64-linux\".";
        default = cachix;
      };
      caches = lib.mkOption {
        description = "
          An attribute set, each `name: value` pair translates to an effect under
          onPush.default.outputs.effects.populate-cache-effect.name
        ";
        example = "
          {
            our-cachix = {
              type = \"cachix\";
              secretName = \"our-cachix-token\";
              branches = [ \"master\" ];
              packages = [ pkgs.hello ];
            };
          }
        ";
        type = lib.types.attrsOf (lib.types.submodule (
          {name, ...}: {
            options = {
              name = lib.mkOption {
                type = lib.types.str;
                default = name;
                description = ''
                  Name of the effect. By default it's the attribute name.
                '';
              };
              type = lib.mkOption {
                type = lib.types.enum ["attic" "cachix"];
                description = "A string \"attic\" or \"cachix\".";
              };
              packages = lib.mkOption {
                type = with lib.types; listOf package;
                description = "List of packages to push to the cache.";
                example = "[ pkgs.hello ]";
              };
              secretName = lib.mkOption {
                type = lib.types.str;
                description = ''
                  Name of the HerculesCI secret. See [HerculesCI docs](https://docs.hercules-ci.com/hercules-ci-agent/secrets-json).
                  The secrets "data" field should contain given data:

                  ```
                    "data": {
                      "name": "my-cache-name",
                      "token": "ey536428341723812",
                      "endpoint": "https://my-cache-name.com"
                    }
                  ```

                  The "endpoint" field is needed for Attic cache. With Cachix cache the "endpoint" field is not read and can be absent.
                '';
              };
              branches = lib.mkOption {
                type = with lib.types; listOf str;
                description = ''
                  Branches on which we'd like to execute the effect.
                '';
              };
            };
          }
        ));
      };
    };
  };

  config = let
    # file with all the package paths written line by line
    # nixpkgs -> [derivation] -> derivation
    packagesFile = pkgs: packages:
      pkgs.writeText "pushed-paths"
      (lib.strings.concatStringsSep "\n" (builtins.map builtins.toString packages));

    mkAtticPushEffect = {
      cacheOptions,
      branch,
    }:
      withSystem "x86_64-linux" (
        {
          hci-effects,
          pkgs,
          ...
        }: let
          pushEffect = hci-effects.mkEffect {
            inputs = [attic-client-pkg];
            secretsMap = {
              token-file = "${cacheOptions.secretName}";
            };
            userSetupScript = ''
              attic login \
                server-name \
                $(readSecretString token-file .endpoint) \
                $(readSecretString token-file .token)
            '';
            effectScript = ''
              cat ${packagesFile pkgs cacheOptions.packages} | xargs -s 4096 attic push server-name:$(readSecretString token-file .name)
            '';
          };
        in
          hci-effects.runIf (builtins.elem branch cacheOptions.branches) pushEffect
      );

    mkCachixPushEffect = {
      cacheOptions,
      branch,
    }:
      withSystem "x86_64-linux" (
        {
          hci-effects,
          pkgs,
          ...
        }: let
          pushEffect = hci-effects.mkEffect {
            inputs = [cachix];
            secretsMap = {
              token-file = "${cacheOptions.secretName}";
            };
            userSetupScript = ''
              cachix authtoken $(readSecretString token-file .token)
            '';
            effectScript = ''
              cat ${packagesFile pkgs cacheOptions.packages} | cachix push $(readSecretString token-file .name)
            '';
          };
        in
          hci-effects.runIf (builtins.elem branch cacheOptions.branches) pushEffect
      );
  in
    lib.mkIf config.populate-cache-effect.enable {
      herculesCI = herculesConfig: {
        onPush.default.outputs.effects.populate-cache-effect =
          lib.attrsets.mapAttrs' (_: cacheOptions: {
            inherit (cacheOptions) name;
            value = builtins.getAttr "${cacheOptions.type}" {
              attic = mkAtticPushEffect {
                inherit cacheOptions;
                inherit (herculesConfig.config.repo) branch;
              };
              cachix = mkCachixPushEffect {
                inherit cacheOptions;
                inherit (herculesConfig.config.repo) branch;
              };
            };
          })
          config.populate-cache-effect.caches;
      };
    };
}
