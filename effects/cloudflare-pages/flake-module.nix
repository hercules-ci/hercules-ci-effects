{ config, lib, withSystem, ... }:
let
  inherit (lib)
    mkOption
    types
    optionalAttrs
    mapAttrs;
  cfg = config.hercules-ci.cloudflare-pages;
in
{
  options.hercules-ci.cloudflare-pages = mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        content = mkOption {
          type = types.functionTo (types.either types.str types.package);
          example = lib.literalExpression "{ config, ... }: config.packages.default";
          description = ''
            A function that returns the site content, also known as the Publish directory.
            This includes files such as index.html, style sheets, etc.
            You will typically put a derivation here.

            The function receives the same arguments as [perSystem](https://flake.parts/options/flake-parts.html#opt-perSystem).
          '';
        };

        secretName = mkOption {
          type = types.str;
          description = ''
            The secret that will be looked up in [secrets.json](https://docs.hercules-ci.com/hercules-ci-agent/secrets-json).
            This secret must hold the `secretField` field, with a string value that is a Cloudflare API token.
          '';
        };

        secretField = mkOption {
          type = types.str;
          default = "token";
          description = "The name of the field inside the `secretName` secret which holds the Cloudflare API token.";
        };

        projectName = mkOption {
          type = types.str;
          description = "The project name you assigned to the website when initializing it.";
        };

        accountId = mkOption {
          type = types.str;
          description = "The Cloudflare account ID which the project is under.";
        };

        branch = mkOption {
          type = types.nullOr (types.functionTo types.str);
          default = null;
          example = lib.literalExpression ''{ branch, ... }: branch'';
          description = ''
            The name of the branch you want to deploy to.
            The function receives the value of attributes under [herculesCI.repo](https://flake.parts/options/hercules-ci-effects.html#opt-herculesCI.repo).
          '';
        };

        secretsMap = mkOption {
          type = types.attrs;
          default = { };
          description = "Extra secrets to add to the effect.";
        };

        extraDeployArgs = mkOption {
          type = (types.listOf types.str);
          default = [ ];
          description = "Extra arguments to pass to the wrangler publish invocation.";
        };

        effect.system = mkOption {
          type = types.str;
          default = config.defaultEffectSystem;
          defaultText = lib.literalMD "config.defaultEffectSystem";
          example = "aarch64-linux";
          description = "The [system](https://nixos.org/manual/nix/stable/command-ref/conf-file.html#conf-system) on which to run the website deployment on.";
        };
      };
    });
  };

  config = {
    herculesCI = herculesCI: {
      onPush.default.outputs.effects = {
        cloudflare-pages = mapAttrs
          (name: projectCfg: optionalAttrs (projectCfg != { }) (withSystem projectCfg.effect.system ({ hci-effects, ... }:
            hci-effects.cloudflarePages {
              inherit (projectCfg)
                secretName
                secretField
                projectName
                accountId
                secretsMap
                extraDeployArgs;
              branch = projectCfg.branch herculesCI.config.repo;
              content = withSystem projectCfg.effect.system projectCfg.content;
            }
          )))
          cfg;
      };
    };
  };
}
