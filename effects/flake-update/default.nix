{ lib
, mkEffect
, pkgs
}:

let
  parseURL = gitRemote:
    let m = builtins.match "([a-z]*)://([^/]*)(/?.*)" gitRemote;
    in if m == null then throw "Could not determine host in gitRemote url ${gitRemote}" else {
      scheme = lib.elemAt m 0;
      host = lib.elemAt m 1;
      path = lib.elemAt m 2;
    };
in

{ gitRemote
, tokenSecret ? { type = "GitToken"; }
, user ? "git"
, updateBranch ? "flake-update"
}:
let
  url = parseURL gitRemote;
in
mkEffect ({
  secretsMap.token = tokenSecret;
  inherit gitRemote user updateBranch;
  inherit (url) scheme host path;

  name = "flake-update";
  inputs = [
    pkgs.git
    pkgs.nix
  ];

  EMAIL = "noreply+hercules-ci-effects@hercules-ci.com";
  GIT_AUTHOR_NAME = "Hercules CI Effects";
  GIT_COMMITTER_NAME = "Hercules CI Effects";
  PAGER = "cat";

  userSetupScript = ''
    # set -x
    echo "$scheme://$user:$(readSecretString token .token)@$host$path" >~/.git-credentials
    git config --global credential.helper store
  '';
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
  '';
})
