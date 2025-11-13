{ config, lib, withSystem, ... }:
let
  inherit (lib)
    mkOption
    types
    optionalAttrs
    mapAttrs;
  cfg = config.hercules-ci.netlify-deploy;
in
{
  options.hercules-ci.netlify-deploy = mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        siteId = mkOption {
          type = types.str;
          description = ''
            An opaque identifier assigned by Netlify to the website you wish to deploy.
            See [docs.hercules-ci.com](https://docs.hercules-ci.com/hercules-ci-effects/reference/nix-functions/netlifydeploy/#param-name) on how to get the right siteId for your website from Netlify.
          '';
        };

        secretName = mkOption {
          type = types.str;
          description = ''
            The secret that will be looked up in [secrets.json](https://docs.hercules-ci.com/hercules-ci-agent/secrets-json).
            This secret must hold the `secretField` field, ith a string value that is a Netlify personal access token.
          '';
        };

        secretField = mkOption {
          type = types.str;
          default = "token";
          description = "The name of the field inside the `secretName` secret which holds the Netlify personal access token.";
        };

        content = mkOption {
          type = types.functionTo (types.either types.str types.package);
          example = lib.literalExpression "{ config, ... }: config.packages.default";
          description = ''
            A function that returns the site content, also known as the Publish directory.
            This includes files such as netlify.toml, _redirects, and all web resources, like index.html, style sheets, etc.
            You will typically put a derivation here.

            The function receives the same arguments as [perSystem](https://flake.parts/options/flake-parts.html#opt-perSystem).
          '';
        };

        productionDeployment = mkOption {
          type = types.functionTo types.bool;
          default = _: false;
          defaultText = lib.literalExpression "_: false";
          example = lib.literalExpression ''{ branch, ... }: (branch == "master")'';
          description = ''
            Condition under which a deployment is treated as a production deployment.
            The function receives the value of attributes under [herculesCI.repo](https://flake.parts/options/hercules-ci-effects.html#opt-herculesCI.repo).
          '';
        };

        extraDeployArgs = mkOption {
          type = (types.listOf types.str);
          default = [ ];
          description = "Extra arguments to pass to the netlify deploy invocation.";
        };

        secretsMap = mkOption {
          type = types.attrs;
          default = { };
          description = "Extra secrets to add to the effect.";
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
        netlify-deploy = mapAttrs
          (name: siteCfg: optionalAttrs (siteCfg != { }) (withSystem siteCfg.effect.system ({ hci-effects, ... }:
            hci-effects.netlifyDeploy {
              inherit (siteCfg)
                siteId
                secretName
                secretField
                extraDeployArgs
                secretsMap;
              productionDeployment = siteCfg.productionDeployment herculesCI.config.repo;
              content = withSystem siteCfg.effect.system siteCfg.content;
            }
          )))
          cfg;
      };
    };
  };
}
