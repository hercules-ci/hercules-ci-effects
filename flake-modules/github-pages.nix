top@{ config, options, lib, inputs, withSystem, getSystem, flake-parts-lib, ... }:
let
  inherit (lib)
    mkIf
    mkMerge
    mkOption
    types
    ;

  inherit (config) defaultEffectSystem;
  inherit (flake-parts-lib) mkPerSystemOption;

  cfg = config.hercules-ci.github-pages;

  enable = cfg.branch != null;

  githubPagesSettings = {
    _file = "${__curPos.file}:let githubPagesSettings";
    git.checkout.forgeType = "github";
    git.checkout.user = "x-access-token";
    git.update.branch = "gh-pages";
  };

in
{
  options = {
    perSystem = mkPerSystemOption ({ config, ... }: {
      options = {
        hercules-ci.github-pages.settings = lib.mkOption {
          type = types.deferredModule;
          description = ''
            Modular settings for the GitHub Pages effect.

            See [`gitWriteBranch`](https://docs.hercules-ci.com/hercules-ci-effects/reference/nix-functions/gitWriteBranch.html#effect_options) for options.
          '';
          example = lib.literalExpression ''
            {
              contents = config.packages.docs + "/share/doc/mypkg/html";
            }
          '';
        };
      };
    });

    hercules-ci.github-pages = {
      branch = lib.mkOption {
        type = types.nullOr types.str;
        description = ''
          A GitHub Pages deployment will be triggered when changes are pushed to this branch.

          A non-null value enables the effect.
        '';
        default = null;
      };
      check.enable = lib.mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether to make sure that the effect is buildable. This adds
          `checks.''${config.defaultEffectSystem}.gh-pages` to `onPush.default`.
        '';
      };
      pushJob = lib.mkOption {
        type = types.str;
        description = ''
          The Hercules CI job in which to perform the deployment.
          
          By default the GitHub pages deployment is triggered by the `onPush.default` job,
          so that the deployment only proceeds when the default builds are successful.
        '';
        default = "default";
      };
      settings = lib.mkOption {
        type = types.deferredModule;
        description = ''
          Modular settings for the GitHub Pages effect.

          For system-dependent settings, define [`perSystem.hercules-ci.github-pages.settings`](#opt-perSystem.hercules-ci.github-pages.settings) instead.

          See [`gitWriteBranch`](https://docs.hercules-ci.com/hercules-ci-effects/reference/nix-functions/gitWriteBranch.html#effect_options) for options.
        '';
        example = lib.literalExpression ''
          {
            message = "Update GitHub Pages";
          }
        '';
      };
    };
  };

  config = mkIf enable {
    perSystem = { hci-effects, system, ... }:
      let
        deploy =
          hci-effects.gitWriteBranch {
            imports = [
              githubPagesSettings
              cfg.settings
            ];
            git.checkout.remote.url = "https://fake-repo-for.checks.github-pages-effect-is-buildable";
          };
      in
      {
        checks = lib.optionalAttrs (system == defaultEffectSystem) {
          github-pages-effect-is-buildable = deploy.tests.buildable;
        };
      };

    hercules-ci.github-pages.settings = (getSystem defaultEffectSystem).hercules-ci.github-pages.settings;

    herculesCI = herculesCI@{ config, ... }:
      let
        deploy = withSystem defaultEffectSystem ({ config, hci-effects, ... }:
          hci-effects.gitWriteBranch {
            imports = [
              githubPagesSettings
              cfg.settings
            ];
            git.checkout.remote.url = herculesCI.config.repo.remoteHttpUrl;
          }
        );
      in
      {
        onPush = mkMerge [
          # deploy
          {
            ${cfg.pushJob}.outputs.effects.gh-pages =
              lib.throwIf (cfg.branch == "gh-pages") ''
                The option `hercules-ci.github-pages.branch` refers to the branch
                that serves as a source for the GitHub Pages deployment. You've set
                it to "gh-pages" which is the output. You'll probably want to
                specify a branch like your default branch, such as "main", "develop"
                or "master", or some other branch that isn't occupied by the build
                output.
              ''
              lib.optionalAttrs
                (herculesCI.config.repo.branch == cfg.branch)
                deploy;
          }
        ];
      };
  };
}
