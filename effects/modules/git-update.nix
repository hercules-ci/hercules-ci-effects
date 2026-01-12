{
  config,
  lib,
  options,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkOption
    optionalAttrs
    optionals
    optionalString
    types
    ;

  cfg = config.git.update;

  githubAutoMerge =
    (cfg.pullRequest.autoMergeMethod != null) && config.git.checkout.forgeType == "github";

  baseMergeMessageOnce = lib.warn "hercules-ci-effects/git-update: `baseMerge.enable` is unset. It will be enabled by default soon. You may silence this warning by setting `baseMerge.enable = true;`. See also `baseMerge.method` to customize how the update branch is brought up to date with the base (\"target\") branch: https://docs.hercules-ci.com/hercules-ci-effects/reference/effect-modules/git#_git_update_basemerge_method" null;

  withBaseMergeMessage =
    if
      options.git.update.baseMerge.enable.highestPrio == (lib.modules.mkOptionDefault null).priority
    then
      builtins.seq baseMergeMessageOnce
    else
      x: x;

in
{
  imports = [
    ../modules/git-auth.nix
    ../modules/git-auth-gh.nix
  ];

  options = {
    git.update = {
      branch = mkOption {
        description = ''
          Branch name to push to.

          If you use pull requests, this should be a "feature" branch.
        '';
        type = types.str;
      };
      script = mkOption {
        description = ''
          Bash statements that create zero or more commits.
          All changes must be explicitly committed by the script.

          The working directory is the root of the checkout.
        '';
        type = types.lines;
      };
      baseBranch = mkOption {
        description = ''
          Branch name on the remote that the update branch will be
            - based on (via `git.update.baseMerge.branch`), and
            - merged back into (via `git.update.pullRequest.base`) if enabled.

          `"HEAD"` refers to the default branch, which is often `main` or `master`.
        '';
        type = types.str;
        default = "HEAD";
      };
      baseMerge.enable = mkOption {
        description = ''
          Whether to update an existing update branch with changes from the base branch before running `git.update.script`.

          This option only applies when the update branch already exists from a previous run.
          The existing branch is likely stale, so enabling this ensures it includes recent changes from the base branch.

          If disabled and the update branch exists, the update script will run from the branch's current state,
          which may be missing recent changes from the base branch.
        '';
        type = types.bool;
        # TODO [baseMerge] enable by default after real world testing
        default = false;
      };
      baseMerge.branch = mkOption {
        description = ''
          Branch name on the remote to update the existing update branch from.

          Typically this should be the same as the target branch for pull requests.
          Used when `git.update.baseMerge.enable` is true and the update branch exists.
        '';
        type = types.str;
        default = cfg.baseBranch;
        defaultText = lib.literalExpression ''
          git.update.baseBranch
        '';
      };
      baseMerge.method = mkOption {
        description = ''
          How to update an existing update branch with changes from the base branch.

          - `"merge"`: Create a merge commit, preserving both branch histories.
            Safe but creates additional merge commits in the update branch.

          - `"rebase"`: Rebase existing update branch commits onto the current base branch.
            Creates a linear history but rewrites commit hashes (requires force push).

          - `"fast-forward"`: Only proceed if the update branch can fast-forward to the base branch.
            Fails if the update branch has any commits not present in the base branch.
            This is the most conservative option, preventing complex merge scenarios.

          - `"reset"`: Always discard the existing update branch and start fresh from the base branch.
            This treats the update branch as fully regeneratable from the update script.
            Useful for automated updates (like flake.lock) where the update script output
            is deterministic and conflicts should be resolved by regenerating.
            Any manual changes to the update branch will be lost.

          The `"fast-forward"` method is recommended for automated workflows where you prefer
          explicit failures over automatic conflict resolution.

          Used when `git.update.baseMerge.enable` is true and the update branch exists.
        '';
        type = types.enum [
          "merge"
          "rebase"
          "fast-forward"
          "reset"
        ];
        default = "merge";
      };
      pullRequest = {
        enable = mkOption {
          description = ''
            Whether to create a pull request to merge the updated branch into the default branch.
          '';
          type = types.bool;
          default = true;
        };
        base = mkOption {
          description = ''
            Branch name on the remote to merge the update branch into.

            Used when `git.update.pullRequest.enable` is true.
          '';
          type = types.str;
          default = cfg.baseBranch;
          defaultText = lib.literalExpression ''
            git.update.baseBranch
          '';
          example = "develop";
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
        title = mkOption {
          type = types.str;
          description = ''
            The title to use for the pull request.

            A more detailed title can be achieved by making `git.update.script` set the title in the `HCI_GIT_UPDATE_PR_TITLE` environment variable.
          '';
        };
        body = mkOption {
          type = types.nullOr types.str;
          description = ''
            The body, or description, of the pull request.

            A more detailed body can be achieved by making `git.update.script` set the
            body contents in the `HCI_GIT_UPDATE_PR_BODY` environment variable.

            If `null`, the body will be empty or automatic based on the commit message.
          '';
        };
      };
    };
  };

  config = {

    env = {
      HCI_GIT_REMOTE_URL = config.git.checkout.remote.url;
      HCI_GIT_UPDATE_BRANCH = cfg.branch;
      HCI_GIT_UPDATE_BASE_BRANCH = cfg.baseMerge.branch;
    }
    // optionalAttrs cfg.pullRequest.enable {
      HCI_GIT_UPDATE_PR_TITLE = cfg.pullRequest.title;
      HCI_GIT_UPDATE_PR_BASE = cfg.pullRequest.base;
    }
    // optionalAttrs (cfg.pullRequest.enable && cfg.pullRequest.body != null) {
      HCI_GIT_UPDATE_PR_BODY = cfg.pullRequest.body;
    }
    // withBaseMergeMessage optionalAttrs cfg.baseMerge.enable {
      HCI_GIT_UPDATE_BASE_MERGE_METHOD = cfg.baseMerge.method;
    };

    effectScript = ''
      git clone "$HCI_GIT_REMOTE_URL" repo
      cd repo
      if git rev-parse "refs/remotes/origin/$HCI_GIT_UPDATE_BRANCH" &>/dev/null; then
        updateBranchExisted=true
      else
        updateBranchExisted=false
      fi
      if [[ "$updateBranchExisted" == "true" && "''${HCI_GIT_UPDATE_BASE_MERGE_METHOD:-}" != "reset" ]]; then
        git checkout "$HCI_GIT_UPDATE_BRANCH"
      else
        # Start fresh from the base branch (either no prior branch, or reset method)
        git checkout -b "$HCI_GIT_UPDATE_BRANCH" "refs/remotes/origin/$HCI_GIT_UPDATE_BASE_BRANCH"
      fi

      function die_conflict(){
        echo 1>&2 "Failed. Please resolve conflicts by hand and push to $HCI_GIT_UPDATE_BASE_BRANCH."
        echo 1>&2 "Conflicts with diff; summary at end:"
        echo 1>&2
        git diff --diff-filter=U --relative
        echo 1>&2
        echo 1>&2 "Conflict summary:"
        echo 1>&2
        # bold red
        printf '\033[1;31m'
        git diff --diff-filter=U --relative --name-only
        # reset
        printf '\033[0m'
        echo 1>&2
        exit 1
      }

      # For reset, we already started fresh from the base branch above
      if [[ "$updateBranchExisted" == "true" && "''${HCI_GIT_UPDATE_BASE_MERGE_METHOD:-}" != "reset" ]]; then
        baseDescr="$(git rev-parse --abbrev-ref "refs/remotes/origin/$HCI_GIT_UPDATE_BASE_BRANCH")"
        case "''${HCI_GIT_UPDATE_BASE_MERGE_METHOD:-}" in
          merge)
            echo "Merging $baseDescr into $HCI_GIT_UPDATE_BRANCH ..."
            git merge "refs/remotes/origin/$HCI_GIT_UPDATE_BASE_BRANCH" || die_conflict
            ;;
          rebase)
            echo "Rebasing $HCI_GIT_UPDATE_BRANCH onto $baseDescr ..."
            git rebase "refs/remotes/origin/$HCI_GIT_UPDATE_BASE_BRANCH" || die_conflict
            ;;
          fast-forward)
            echo "Fast-forwarding $HCI_GIT_UPDATE_BRANCH to $baseDescr ..."
            if ! git merge --ff-only "refs/remotes/origin/$HCI_GIT_UPDATE_BASE_BRANCH"; then
              echo 1>&2 ""
              echo 1>&2 "Current branch state:"
              mergeBase=$(git merge-base "refs/remotes/origin/$HCI_GIT_UPDATE_BASE_BRANCH" "refs/remotes/origin/$HCI_GIT_UPDATE_BRANCH" 2>/dev/null || echo "")
              if [ -z "$mergeBase" ]; then
                echo 1>&2 "ERROR: Branches '$HCI_GIT_UPDATE_BRANCH' and '$baseDescr' share no common history!"
                echo 1>&2 "This indicates a serious repository problem. The update branch appears to be"
                echo 1>&2 "from a completely different repository or was created incorrectly."
                echo 1>&2 ""
                echo 1>&2 "Recent commits on each branch:"
                echo 1>&2 "=== $HCI_GIT_UPDATE_BRANCH ==="
                git log --oneline -5 "refs/remotes/origin/$HCI_GIT_UPDATE_BRANCH" >&2 || true
                echo 1>&2 "=== $baseDescr ==="
                git log --oneline -5 "refs/remotes/origin/$HCI_GIT_UPDATE_BASE_BRANCH" >&2 || true
                false
              fi

              git log --oneline --graph --decorate "$mergeBase^.." "refs/remotes/origin/$HCI_GIT_UPDATE_BRANCH" "refs/remotes/origin/$HCI_GIT_UPDATE_BASE_BRANCH" >&2 || true

              echo 1>&2 ""
              echo 1>&2 "Fast-forward failed: '$HCI_GIT_UPDATE_BRANCH' has commits that are not in '$baseDescr'."
              echo 1>&2 ""
              echo 1>&2 "The update branch has diverged from the base branch and cannot be fast-forwarded."
              echo 1>&2 "This happens when:"
              echo 1>&2 "  - previous update branch was never merged"
              echo 1>&2 "  - and base branch has new commits since the last update"
              echo 1>&2 "  - or multiple update jobs ran concurrently"
              echo 1>&2 ""
              echo 1>&2 "One-off solutions:"
              echo 1>&2 "  a. Delete the update branch and re-run the effect: git push origin :$HCI_GIT_UPDATE_BRANCH"
              echo 1>&2 "  b. Merge or rebase $HCI_GIT_UPDATE_BRANCH"
              echo 1>&2 "Structural solutions:"
              echo 1>&2 "  a. Change baseMerge.method to 'merge' (creates merge commits)"
              echo 1>&2 "  b. Change baseMerge.method to 'rebase' (rewrites history)"
              echo 1>&2 "See https://docs.hercules-ci.com/hercules-ci-effects/reference/effect-modules/git#_git_update_basemerge_method"
              exit 1
            fi
            ;;
          # "reset" case unreachable
        esac
        unset baseDescr
      fi

      rev_before="$(git rev-parse HEAD)"

      ${cfg.script}

      # Require all changes to be committed
      if ! git diff HEAD --exit-code; then
        echo 1>&2 'Uncommitted changes detected. To avoid ignoring changes by accident, `git.update.script` must commit all changes or revert them.'
        exit 1
      fi

      rev_after="$(git rev-parse HEAD)"

      if [[ "$rev_before" == "$rev_after" ]]; then
        echo 1>&2 'No updates to push.'
      else
        declare -a gitPushArgs
        case "''${HCI_GIT_UPDATE_BASE_MERGE_METHOD:-}" in
          rebase)
            gitPushArgs+=(--force-with-lease)
            ;;
          reset)
            # When resetting, we discard prior changes, so we also discard concurrent changes
            gitPushArgs+=(--force)
            ;;
          fast-forward)
            # Fast-forward never requires force push since it only moves forward
            ;;
        esac
        git push origin "$HCI_GIT_UPDATE_BRANCH" ''${gitPushArgs[@]}
      fi
    ''
    + optionalString cfg.pullRequest.enable ''
      # Too many PRs is better than to few. Ensure that the PR exists
      if git rev-parse "refs/remotes/origin/$HCI_GIT_UPDATE_BRANCH" &>/dev/null; then
        prCreateArgs=()

        # Check that HCI_GIT_UPDATE_PR_BODY is set, including empty.
        if [[ -n "''${HCI_GIT_UPDATE_PR_BODY+x}" ]]; then
          prCreateArgs+=(--body "$HCI_GIT_UPDATE_PR_BODY")
        else
          # > Do not prompt for title/body and just use commit info
          prCreateArgs+=(--fill)
        fi

        if [[ "$HCI_GIT_UPDATE_PR_BASE" != "HEAD" ]]; then
          prCreateArgs+=(--base "$HCI_GIT_UPDATE_PR_BASE")
        fi

        if gh pr create \
                  --head "$HCI_GIT_UPDATE_BRANCH" \
                  --title "$HCI_GIT_UPDATE_PR_TITLE" \
                  "''${prCreateArgs[@]}" \
                  2> >(tee $TMPDIR/pr.err) \
                  > $TMPDIR/pr.out
        then
          cat $TMPDIR/pr.out
          ${optionalString githubAutoMerge (
            import ./github-auto-merge.nix {
              inherit lib;
              inherit (cfg.pullRequest) autoMergeMethod;
            }
          )}
        else
          # Expect an error if the PR already exists.
          if grep -E 'a pull request for branch .* already exists' <$TMPDIR/pr.err >/dev/null; then
            # Self explanatory error
            :
          elif grep 'No commits between' <$TMPDIR/pr.err >/dev/null; then
            # Explain printed error, which is something like
            # pull request create failed: GraphQL: No commits between master and flake-update (createPullRequest)
            echo 1>&2 "No commits to merge, so we're already up to date!"
          else
            # A message has already been printed.
            exit 1
          fi
        fi
      fi
    '';
  };
}
