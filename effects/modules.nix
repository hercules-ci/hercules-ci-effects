/*
  Modules for use in `modularEffect`.

  Flake:

      hercules-ci-effects.modules.effect.*

  Alternative:

      hci-effects.modules.*

*/
{
  /*
    Git authentication

    See https://docs.hercules-ci.com/hercules-ci-effects/reference/effect-modules/git#git-auth
  */
  git-auth = ./modules/git-auth.nix;

  /*
    GitHub authentication for the `gh` command. Not needed if you only use git.
  */
  git-auth-gh = ./modules/git-auth-gh.nix;

  /*
    Logic for updating a git branch.

    See https://docs.hercules-ci.com/hercules-ci-effects/reference/effect-modules/git#git-update
  */
  git-update = ./modules/git-update.nix;

  /*
    Very basic git configuration; default author, adding git to PATH, etc.
  */
  git = ./modules/git.nix;
}