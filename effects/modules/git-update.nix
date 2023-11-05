{ config, lib, pkgs, ... }:
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
    (cfg.pullRequest.autoMergeMethod != null)
    && config.git.checkout.forgeType == "github";

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
          Whether to merge the base branch into the update branch before running `git.update.script`.

          This is useful to ensure that the update branch is up to date with the base branch.

          If this option is `false`, you may have to merge or rebase the update branch manually sometimes.
        '';
        type = types.bool;
        # TODO [baseMerge] enable by default after real world testing
        default = false;
      };
      baseMerge.branch = mkOption {
        description = ''
          Branch name on the remote to merge into the update branch before running `git.update.script`.

          Used when `git.update.baseMerge.enable` is true.
        '';
        type = types.str;
        default = cfg.baseBranch;
        defaultText = lib.literalExpression ''
          git.update.baseBranch
        '';
      };
      baseMerge.method = mkOption {
        description = ''
          How to merge the base branch into the update branch before running `git.update.script`.

          Used when `git.update.baseMerge.enable` is true.
        '';
        type = types.enum [ "merge" "rebase" ];
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
          type = types.enum [ null "merge" "rebase" "squash" ];
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
    // optionalAttrs cfg.baseMerge.enable {
      HCI_GIT_UPDATE_BASE_MERGE_METHOD = cfg.baseMerge.method;
    };

    effectScript = ''
      git clone "$HCI_GIT_REMOTE_URL" repo
      cd repo
      if git rev-parse "refs/remotes/origin/$HCI_GIT_UPDATE_BRANCH" &>/dev/null; then
        git checkout "$HCI_GIT_UPDATE_BRANCH"
        updateBranchExisted=true
      else
        git checkout -b "$HCI_GIT_UPDATE_BRANCH" "refs/remotes/origin/$HCI_GIT_UPDATE_BASE_BRANCH"
        updateBranchExisted=false
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

      if [[ "$updateBranchExisted" == "true" ]]; then
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
        esac
        git push origin "$HCI_GIT_UPDATE_BRANCH" ''${gitPushArgs[@]}
      fi
    '' + optionalString cfg.pullRequest.enable ''
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
          ${optionalString githubAutoMerge (import ./github-auto-merge.nix { inherit lib; inherit (cfg.pullRequest) autoMergeMethod; })}
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
