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

modularEffect {
  imports = [
    ../modules/git-update.nix
  ];

  git.checkout.remote.url = gitRemote;
  git.checkout.forgeType = forgeType;
  git.checkout.user = user;

  git.update.branch = updateBranch;
  git.update.pullRequest.enable = createPullRequest;
  git.update.pullRequest.title = "`flake.lock`: Update";
  git.update.pullRequest.body = ''
    Update `flake.lock`. See the commit message(s) for details.

    You may reset this branch by deleting it and re-running the update job.

        git push origin :${updateBranch}
  '';

  secretsMap.token = tokenSecret;

  name = "flake-update";
  inputs = [
    pkgs.nix
  ];

  git.update.script = ''
    echo 1>&2 'Running nix flake update...'
    nix flake update \
      --commit-lock-file \
      --extra-experimental-features 'nix-command flakes'
  '';

}
