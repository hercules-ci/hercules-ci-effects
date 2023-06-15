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
  git-auth = ./effects/modules/git-auth.nix;

  /*
    GitHub authentication for the `gh` command. Not needed if you only use git.
  */
  git-auth-gh = ./effects/modules/git-auth-gh.nix;

  /*
    Logic for updating a git branch.

    See https://docs.hercules-ci.com/hercules-ci-effects/reference/effect-modules/git#git-update
  */
  git-update = ./effects/modules/git-auth.nix;

  /*
    Very basic git configuration; default author, adding git to PATH, etc.
  */
  git = ./effects/modules/git.nix;
}