{ config, lib, withSystem, ... }:
let
  inherit (lib) mkOption types optionalAttrs;
  cfg = config.hercules-ci.flake-update;

  flakeConfigModule = {
    options = {
      inputs = mkOption {
        type = types.listOf types.str;
        default = [];
        example = ''["nixpkgs" "nixpkgs-unstable"]'';
        description = ''
          Flake inputs to update. The default, `[]` means to update all inputs.
        '';
      };

      commitSummary = mkOption {
        type = types.str;
        default = "";
        example = "chore: update flake inputs";
        description = ''
          Summary for commit. "" means to use the default.
        '';
      };
    };
  };

in
{
  options.hercules-ci.flake-update = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether to create a scheduled flake update job.

        For a complete example, see [the hercules-ci-effects documentation on `hercules-ci.flake-update`](https://docs.hercules-ci.com/hercules-ci-effects/reference/flake-parts/flake-update/).

        _Requires hercules-ci-agent 0.9.8 or newer._
      '';
    };

    updateBranch = mkOption {
      type = types.str;
      default = "flake-update";
      example = "update";
      description = ''
        To which branch to push the updated `flake lock`.
      '';
    };

    forgeType = mkOption {
      type = types.str;
      default = "github";
      example = "gitlab";
      description = ''
        The type of Git server commited to.
      '';
    };

    createPullRequest = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to create a pull request for the updated `flake.lock`.
      '';
    };

    autoMergeMethod = mkOption {
      type = types.enum [ null "merge" "rebase" "squash" ];
      default = null;
      description = ''
        Whether to enable auto-merge on new pull requests, and how to merge it.

        This requires [GitHub branch protection](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/defining-the-mergeability-of-pull-requests/about-protected-branches) to be configured for the repository.
      '';
    };

    when = mkOption {
      type = types.raw;
      description = ''
        See [`herculesCI.onSchedule.<name>.when`](#opt-herculesCI.onSchedule._name_.when) for details.
      '';
    };

    effect.system = mkOption {
      type = types.str;
      default = config.defaultEffectSystem;
      defaultText = lib.literalExpression "config.defaultEffectSystem";
      example = "aarch64-linux";
      description = ''
        The [system](https://nixos.org/manual/nix/stable/command-ref/conf-file.html#conf-system) on which to run the flake update job.
      '';
    };

    pullRequestTitle = mkOption {
      type = types.str;
      default = "`flake.lock`: Update";
      example = "chore: update flake.lock";
      description = ''
        The title of the pull request being made
      '';
    };

    pullRequestBody = mkOption {
      type = types.nullOr types.str;
      default = ''
        Update `flake.lock`. See the commit message(s) for details.

        You may reset this branch by deleting it and re-running the update job.

            git push origin :${cfg.updateBranch}
      '';
      example = "updated flake.lock";
      description = ''
        The body of the pull request being made
      '';
    };

    flakes = mkOption {
      type = types.attrsOf (types.submodule flakeConfigModule);
      default = { "." = { }; };
      example = {
        "." = { commitSummary = "/flake.lock: Update"; };
        "path/to/subflake" = { inputs = [ "nixpkgs" ]; };
      };
      description = ''
        Flakes to update.

        The attribute names refer to the relative paths where the flakes/subflakes are located in the repository.

        The values specify further details about how to update the lock. See the sub-options for details.

        NOTE: If you provide a definition for this option, it does *not* extend the default. You must specify all flakes you want to update, including the project root (`"."`) if applicable.
      '';
    };
  };

  config = {
    herculesCI = herculesCI@{ config, ... }: optionalAttrs (cfg.enable) {
      onSchedule.flake-update = {
        inherit (cfg) when;
        outputs = {
          effects = {
            flake-update = withSystem cfg.effect.system ({ config, pkgs, hci-effects, ... }:
              hci-effects.flakeUpdate {
                gitRemote = herculesCI.config.repo.remoteHttpUrl;
                user = "x-access-token";
                inherit (cfg) updateBranch forgeType createPullRequest autoMergeMethod pullRequestTitle pullRequestBody flakes;
              }
            );
          };
        };
      };
    };
  };
}
