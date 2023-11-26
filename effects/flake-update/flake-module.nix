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
        Whether to merge the base branch into the update branch before running the update.

        This is useful to ensure that the update branch is up to date with the base branch.

        If this option is `false`, you may have to merge or rebase the update branch manually sometimes.
      '';
      type = types.bool;
      default = false;
    };

    baseMerge.branch = mkOption {
      description = ''
        Branch name on the remote to merge into the update branch before running the update.

        Used when `hercules-ci.flake-update.baseMerge.enable` is true.
      '';
      type = types.str;
      default = cfg.baseBranch;
      defaultText = lib.literalExpression "hercules-ci.flake-update.baseBranch";
    };

    baseMerge.method = mkOption {
      description = ''
        How to merge the base branch into the update branch before running the update.

        Used when `hercules-ci.flake-update.baseMerge.enable` is true.
      '';
      type = types.enum [ "merge" "rebase" ];
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

    effect.settings = mkOption {
      type = types.deferredModule;
      default = {};
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
      git.update.baseMerge = cfg.baseMerge;
      git.update.baseBranch = cfg.baseBranch;
    };
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
                nix = withSystem cfg.effect.system cfg.nix.package;
                module = cfg.effect.settings;
              }
            );
          };
        };
      };
    };
  };
}
