{ config, lib, withSystem, ... }:
let
  inherit (lib) mkOption types optionalAttrs mapAttrs;
  cfg = config.netlify-deploy;
in
{
  perSystem = { hci-effects, ... }: {
    herculesCI = { config, ... }:
      let cfg = config.netlify-deploy;
      in {
        options = {
          netlify-deploy = mkOption {
            type = types.attrsOf
              (types.submodule {
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
                    type = types.str;
                    description = ''
                      Path to the site content, also known as the Publish directory.
                      This includes files such as netlify.toml, _redirects, and all web resources, like index.html, style sheets, etc.
                      You will typically put a derivation here.
                    '';
                  };

                  productionDeployment = mkOption {
                    type = types.bool;
                    default = false;
                    description = "Whether this should be production deployment.";
                  };

                  extraDeployArgs = mkOption {
                    type = (types.listOf types.str);
                    default = [ ];
                    description = "Extra arguments to pass to the netlify deploy invocation.";
                  };
                };
              });
          };
        };
        config = {
          onPush.effects =
            mapAttrs
              (name: siteCfg: hci-effects.netlifyDeploy {
                inherit (siteCfg) siteId secretName secretField content extraDeployArgs;
                productionDeployment = config.repo.branch == builtins.trace cfg siteCfg.productionBranch;
              })
              cfg;
        };
      };
  };
}
