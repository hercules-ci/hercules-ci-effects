{ lib
, modularEffect
, pkgs
}:

let
  inherit (lib) optionals optionalAttrs optionalString;
in

{ gitRemote
, tokenSecret ? { type = "GitToken"; }
, user ? "git"
, updateBranch ? "flake-update"
, forgeType ? "github"
, createPullRequest ? true
, autoMergeMethod ? null
}:
assert createPullRequest -> forgeType == "github";
assert (autoMergeMethod != null) -> forgeType == "github";

let
  githubPR = createPullRequest && forgeType == "github";
  githubAutoMerge = (autoMergeMethod != null) && forgeType == "github";
  prAttrs = optionalAttrs createPullRequest {
    title = "`flake.lock`: Update";
    body = ''
      Update `flake.lock`. See the commit message(s) for details.

      You may reset this branch by deleting it and re-running the update job.

          git push origin :${updateBranch}
    '';
  };
in
modularEffect {
  imports = [
    ../modules/git-auth.nix
    ../modules/git-auth-gh.nix
  ];

  git.checkout.remote.url = gitRemote;
  git.checkout.forgeType = forgeType;
  git.checkout.user = user;

  secretsMap.token = tokenSecret;

  name = "flake-update";
  inputs = [
    pkgs.nix
  ] ++ optionals githubPR [
    pkgs.gh
  ];

  env = {
    inherit gitRemote updateBranch;
  } // prAttrs;

  effectScript = ''
    git clone "$gitRemote" repo
    cd repo
    if git rev-parse "refs/remotes/origin/$updateBranch" &>/dev/null; then
      git checkout "$updateBranch"
    else
      git checkout -b "$updateBranch"
    fi

    rev_before="$(git rev-parse HEAD)"

    echo 1>&2 'Running nix flake update...'

    nix flake update \
      --commit-lock-file \
      --extra-experimental-features 'nix-command flakes'

    rev_after="$(git rev-parse HEAD)"

    if [[ $rev_before == $rev_after ]]; then
      echo 1>&2 'No updates to push.'
    else
      git push origin "$updateBranch"
    fi
  '' + optionalString githubPR ''
    # Too many PRs is better than to few. Ensure that the PR exists
    if git rev-parse "refs/remotes/origin/$updateBranch" &>/dev/null; then
      if gh pr create \
                --head "$updateBranch" \
                --title "$title" \
                --body "$body" \
                2> >(tee $TMPDIR/pr.err) \
                > $TMPDIR/pr.out
      then
        cat $TMPDIR/pr.out
        ${optionalString githubAutoMerge (import ./github-auto-merge.nix { inherit lib autoMergeMethod; })}
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
}
