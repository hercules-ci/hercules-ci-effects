{
  config,
  lib,
  options,
  withSystem,
  ...
}:
let
  inherit (lib) mkOption types optionalAttrs;
  cfg = config.hercules-ci.flake-update;

  flakeConfigModule = {
    options = {
      inputs = mkOption {
        type = types.listOf types.str;
        default = [ ];
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

  baseMergeEnableOpt = options.hercules-ci.flake-update.baseMerge.enable;

  baseMergeMessageOnce = lib.warn "hercules-ci-effects/flake-update: `${baseMergeEnableOpt}` is unset. It will be enabled by default soon. You may silence this warning by setting `baseMerge.enable = true;`. See also `baseMerge.method` to customize how the update branch is brought up to date with the base (\"target\") branch: https://flake.parts/options/hercules-ci-effects.html#opt-hercules-ci.flake-update.baseMerge.method" null;

  withBaseMergeMessage =
    if baseMergeEnableOpt.highestPrio == (lib.modules.mkOptionDefault null).priority then
      builtins.seq baseMergeMessageOnce
    else
      x: x;

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

    baseBranch = mkOption {
      type = types.str;
      default = "HEAD";
      example = "develop";
      description = ''
        Branch name on the remote that the update branch will be
          - based on (via `hercules-ci.flake-update.baseMerge.branch`), and
          - merged back into if `hercules-ci.flake-update.createPullRequest` is enabled.

        `"HEAD"` refers to the default branch, which is often `main` or `master`.
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

    baseMerge.enable = mkOption {
      description = ''
        Whether to update an existing update branch with changes from the base branch before running the update.

        This option only applies when the update branch already exists from a previous run.
        The existing branch is likely stale, so enabling this ensures it includes recent changes from the base branch.

        If disabled and the update branch exists, the update will run from the branch's current state,
        which may be missing recent changes from the base branch.
      '';
      type = types.bool;
      default = false;
    };

    baseMerge.branch = mkOption {
      description = ''
        Branch name on the remote to update the existing update branch from.

        Typically this should be the same as the target branch for pull requests.
        Used when `hercules-ci.flake-update.baseMerge.enable` is true and the update branch exists.
      '';
      type = types.str;
      default = cfg.baseBranch;
      defaultText = lib.literalExpression "hercules-ci.flake-update.baseBranch";
    };

    baseMerge.method = mkOption {
      description = ''
        How to merge the base branch into the update branch before running the update.

        - `"merge"`: Create a merge commit, preserving the branch history.
        - `"rebase"`: Rebase the update branch commits onto the base branch.
        - `"fast-forward"`: Fast-forward the update branch to the base branch if possible, otherwise fail.
        - `"reset"`: Always discard the existing update branch and start fresh from the base branch.
          Any manual changes to the update branch will be lost.

        The `"fast-forward"` method is the most conservative, equivalent to deleting the stale
        update branch and recreating it from the base branch.

        Used when `hercules-ci.flake-update.baseMerge.enable` is true.
      '';
      type = types.enum [
        "merge"
        "rebase"
        "fast-forward"
        "reset"
      ];
      default = "merge";
    };

    createPullRequest = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to create a pull request for the updated `flake.lock`.
      '';
    };

    autoMergeMethod = mkOption {
      type = types.enum [
        null
        "merge"
        "rebase"
        "squash"
      ];
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

    effect.settings = mkOption {
      type = types.deferredModule;
      default = { };
      description = ''
        A module that extends the flake-update effect arbitrarily.

        See also:
         - [Effect Modules / Core Options](https://docs.hercules-ci.com/hercules-ci-effects/reference/effect-modules/core)
         - [Effect Modules / Git Options](https://docs.hercules-ci.com/hercules-ci-effects/reference/effect-modules/git)
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
      default = {
        "." = { };
      };
      example = {
        "." = {
          commitSummary = "/flake.lock: Update";
        };
        "path/to/subflake" = {
          inputs = [ "nixpkgs" ];
        };
      };
      description = ''
        Flakes to update.

        The attribute names refer to the relative paths where the flakes/subflakes are located in the repository.

        The values specify further details about how to update the lock. See the sub-options for details.

        NOTE: If you provide a definition for this option, it does *not* extend the default. You must specify all flakes you want to update, including the project root (`"."`) if applicable.
      '';
    };

    nix.package = mkOption {
      type = types.functionTo types.package;
      description = ''
        The Nix package to use for performing the lockfile updates.

        The function arguments are the module arguments of `perSystem` for `hercules-ci.flake-update.effect.system`.
      '';
      default = { pkgs, ... }: pkgs.nix;
      defaultText = lib.literalExpression "{ pkgs, ... }: pkgs.nix";
    };
  };

  config = {
    hercules-ci.flake-update.effect.settings = {
      git.update.baseMerge = withBaseMergeMessage cfg.baseMerge;
      git.update.baseBranch = cfg.baseBranch;
    };
    herculesCI =
      herculesCI@{ config, ... }:
      optionalAttrs (cfg.enable) {
        # NOTE: when generalizing to multiple schedules, check that the branches don't interfere.
        onSchedule.flake-update = {
          inherit (cfg) when;
          outputs = {
            effects = {
              flake-update = withSystem cfg.effect.system (
                {
                  config,
                  pkgs,
                  hci-effects,
                  ...
                }:
                hci-effects.flakeUpdate {
                  gitRemote = herculesCI.config.repo.remoteHttpUrl;
                  user = "x-access-token";
                  inherit (cfg)
                    updateBranch
                    forgeType
                    createPullRequest
                    autoMergeMethod
                    pullRequestTitle
                    pullRequestBody
                    flakes
                    ;
                  nix = withSystem cfg.effect.system cfg.nix.package;
                  module = cfg.effect.settings;
                }
              );
            };
          };
        };
        # Make the warning visible in jobs like config and onPush.default too.
        onPush = withBaseMergeMessage { };
      };
  };
}
