{ config, lib, pkgs, ... }:
let
  inherit (lib)
    mkOption
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
          Branch name to pull from and push any changes to.
        '';
        type = types.str;
      };
      script = mkOption {
        description = ''
          Bash statements that make changes to the checkout.

          The working directory is the root of the checkout.
        '';
        type = types.lines;
      };
      pullRequest = {
        enable = mkOption {
          description = ''
            Whether to create a pull request to merge the updated branch into the default branch.
          '';
          type = types.bool;
          default = true;
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
          type = types.str;
          description = ''
            The body, or description, of the pull request.

            A more detailed body can be achieved by making `git.update.script` set the
            body contents in the `HCI_GIT_UPDATE_PR_BODY` environment variable.
          '';
        };
      };
    };
  };

  config = {

    env = {
      HCI_GIT_REMOTE_URL = config.git.checkout.remote.url;
      HCI_GIT_UPDATE_BRANCH = cfg.branch;
      HCI_GIT_UPDATE_PR_TITLE = cfg.pullRequest.title;
      HCI_GIT_UPDATE_PR_BODY = cfg.pullRequest.body;
    };

    effectScript = ''
      git clone "$HCI_GIT_REMOTE_URL" repo
      cd repo
      if git rev-parse "refs/remotes/origin/$HCI_GIT_UPDATE_BRANCH" &>/dev/null; then
        git checkout "$HCI_GIT_UPDATE_BRANCH"
      else
        git checkout -b "$HCI_GIT_UPDATE_BRANCH"
      fi

      rev_before="$(git rev-parse HEAD)"

      ${cfg.script}

      rev_after="$(git rev-parse HEAD)"

      if [[ "$rev_before" == "$rev_after" ]]; then
        echo 1>&2 'No updates to push.'
      else
        git push origin "$HCI_GIT_UPDATE_BRANCH"
      fi
    '' + optionalString cfg.pullRequest.enable ''
      # Too many PRs is better than to few. Ensure that the PR exists
      if git rev-parse "refs/remotes/origin/$HCI_GIT_UPDATE_BRANCH" &>/dev/null; then
        if gh pr create \
                  --head "$HCI_GIT_UPDATE_BRANCH" \
                  --title "$HCI_GIT_UPDATE_PR_TITLE" \
                  --body "$HCI_GIT_UPDATE_PR_BODY" \
                  2> >(tee $TMPDIR/pr.err) \
                  > $TMPDIR/pr.out
        then
          cat $TMPDIR/pr.out
          ${optionalString githubAutoMerge (import ./github-auto-merge.nix { inherit lib; inherit (cfg) autoMergeMethod; })}
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
