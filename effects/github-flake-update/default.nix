{ lib
, mkEffect
, pkgs
}:

args@{ gitRemote
, tokenSecret
, ...
}:
mkEffect ({
  secretsMap.token = tokenSecret;
  GIT_AUTHOR_NAME = "Hercules CI Effects";
  GIT_COMMITTER_NAME = "Hercules CI Effects";
  EMAIL = "noreply+hercules-ci-effects@hercules-ci.com";
  PAGER = "cat";
  github = "github.com";
  message = "Update flake.lock";
  title = "Update flake.lock";
  updateBranch = "flake-update";
  body = ''
    Generated by [hercules-ci-effects](https://docs.hercules-ci.com/hercules-ci-effects).

    You can reset this branch by deleting it and re-running the update job.

        git push origin :${args.updateBranch or "flake-update"}

  '';
  name = "flake-update";
  dontUnpack = true;
} // args // {
  nativeBuildInputs = args.nativeBuildInputs or [ ] ++ [
    pkgs.git
    pkgs.procps
    pkgs.nix
    pkgs.gh
  ];
  userSetupScript = ''
    echo "https://git:$(readSecretString token .token)@$github" >~/.git-credentials
    git config --global credential.helper store
    mkdir -p ~/.config/gh
    { echo "$github:"
      echo "  oauth_token: $(readSecretString token .token)"
    } >~/.config/gh/hosts.yml
  '';
  effectScript = ''
    git clone $gitRemote repo
    cd repo
    if git rev-parse "refs/remotes/origin/$updateBranch" &>/dev/null; then
      git checkout "$updateBranch"
    else
      git checkout -b "$updateBranch"
    fi

    commit0="$(git rev-parse HEAD)"

    echo 1>&2 'Running nix flake update...'

    nix flake update \
      --commit-lock-file \
      --extra-experimental-features 'nix-command flakes'

    commit1="$(git rev-parse HEAD)"

    if [[ $commit0 == $commit1 ]]; then
      echo 1>&2 'No updates to push.'
    else
      git push origin "$updateBranch"
    fi

    # Too many PRs is better than to few. Ensure that the PR exists
    if git rev-parse "refs/remotes/origin/$updateBranch" &>/dev/null; then
      if ! gh pr create \
                --head "$updateBranch" \
                --title "$title" \
                --body "$body" \
                2>&1 \
            | tee $TMPDIR/pr.err
      then
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
})
