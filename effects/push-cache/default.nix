{ lib, withSystem, config, ... }:
let pkgs-x86_64-linux = withSystem "x86_64-linux" ({ pkgs, ... }: pkgs);
in {
  imports = [ ../../flake-module.nix ];

  options = {
    push-cache-effect = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enables an effect that pushes certain outputs to a different binary cache.

          Hercules CI normally pushes everything to the cache(s) configured on the agent. This effect supplements that behavior by letting you push a subset of those to a different cache.
          Note that it only pushes the output closure, and not the closures of build dependencies used during the build stage of the CI job. (Unless those closures happen to also be part of the output or "runtime" closure)
        '';
      };
      attic-client-pkg = lib.mkOption {
        type = lib.types.package;
        description = ''
          Version of the attic-client package to use on \"x86_64-linux\".

          Hint: You can use `attic.packages.x86_64-linux.attic-client` from the attic flake.
        '';
        default = pkgs-x86_64-linux.attic-client or (throw
          "push-cache-effect.attic-client-pkg: It seems that attic hasn't been packaged in Nixpkgs (yet?). Please check <nixpkgs packaging request issue> or set <option> manually.");
      };
      cachix-pkg = lib.mkOption {
        type = lib.types.package;
        default = pkgs-x86_64-linux.cachix;
        description =
          ''Version of the cachix package to use on "x86_64-linux".'';
      };
      caches = lib.mkOption {
        description =
          "\n          An attribute set, each `name: value` pair translates to an effect under\n          onPush.default.outputs.effects.push-cache-effect.name\n        ";
        example =
          "\n          {\n            our-cachix = {\n              type = \"cachix\";\n              secretName = \"our-cachix-token\";\n              branches = [ \"master\" ];\n              packages = [ pkgs.hello ];\n            };\n          }\n        ";
        type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              default = name;
              description = ''
                Name of the effect. By default it's the attribute name.
              '';
            };
            type = lib.mkOption {
              type = lib.types.enum [ "attic" "cachix" ];
              description = ''A string "attic" or "cachix".'';
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
              type = with lib.types; nullOr (listOf str);
              default = null;
              description = ''
                Branches on which we'd like to execute the effect. Set to `null` to execute on all branches.
              '';
            };
          };
        }));
      };
    };
  };

  config = let
    # file with all the package paths written line by line
    # nixpkgs -> [derivation] -> derivation
    packagesFile = pkgs: packages:
      pkgs.writeText "pushed-paths" (lib.strings.concatStringsSep "\n"
        (builtins.map builtins.toString packages));

    mkAtticPushEffect = { cacheOptions, branch, }:
      withSystem "x86_64-linux" ({ hci-effects, pkgs, ... }:
        let
          pushEffect = hci-effects.mkEffect {
            inputs = [ config.push-cache-effect.attic-client-pkg ];
            secretsMap = { token-file = "${cacheOptions.secretName}"; };
            userSetupScript = ''
              attic login \
                server-name \
                $(readSecretString token-file .endpoint) \
                $(readSecretString token-file .token)
            '';
            effectScript = ''
              cat ${
                packagesFile pkgs cacheOptions.packages
              } | xargs -s 4096 attic push server-name:$(readSecretString token-file .name)
            '';
          };
        in hci-effects.runIf ((cacheOptions.branches == null)
          || (builtins.elem branch cacheOptions.branches)) pushEffect);

    mkCachixPushEffect = { cacheOptions, branch, }:
      withSystem "x86_64-linux" ({ hci-effects, pkgs, ... }:
        let
          pushEffect = hci-effects.mkEffect {
            inputs = [ config.push-cache-effect.cachix-pkg ];
            secretsMap = { token-file = "${cacheOptions.secretName}"; };
            userSetupScript = ''
              cachix authtoken $(readSecretString token-file .token)
            '';
            effectScript = ''
              cat ${
                packagesFile pkgs cacheOptions.packages
              } | cachix push $(readSecretString token-file .name)
            '';
          };
        in hci-effects.runIf (builtins.elem branch cacheOptions.branches)
        pushEffect);
  in lib.mkIf config.push-cache-effect.enable {
    herculesCI = herculesConfig: {
      onPush.default.outputs.effects.push-cache-effect = lib.attrsets.mapAttrs'
        (_: cacheOptions: {
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
        }) config.push-cache-effect.caches;
    };
  };
}
