{ lib
, modularEffect
, pkgs
}:

let
  inherit (builtins) concatStringsSep;
  inherit (lib) forEach optionals optionalAttrs optionalString;
in

{ gitRemote
, tokenSecret ? { type = "GitToken"; }
, user ? "git"
, updateBranch ? "flake-update"
, forgeType ? "github"
, createPullRequest ? true
, autoMergeMethod ? null
  # NB: Default also specified in ./flake-module.nix
, pullRequestTitle ? "`flake.lock`: Update"
, pullRequestBody ? null
, inputs ? []
, commitSummary ? ""
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
  git.update.pullRequest.title = pullRequestTitle;
  git.update.pullRequest.body = pullRequestBody;
  git.update.pullRequest.autoMergeMethod = autoMergeMethod;

  secretsMap.token = tokenSecret;

  name = "flake-update";
  inputs = [
    pkgs.nix
  ];

  git.update.script =
  let
    isSet = inputs != [];
    hasSummary = commitSummary != "";
    extraArgs = concatStringsSep " " (forEach inputs (i: "--update-input ${i}"));
    command = if isSet then "flake lock" else "flake update";
  in ''
    echo 1>&2 'Running nix ${command}...'
    nix ${command} ${extraArgs} \
      --commit-lock-file \
      ${optionalString hasSummary "--commit-lockfile-summary \"${commitSummary}\""} \
      --extra-experimental-features 'nix-command flakes'
  '';

}
