{ config, lib, options, pkgs, ... }:
let
  inherit (lib)
    mkOption
    types
    ;
  cfg = config.git.checkout;
  opt = options.git.checkout;

  parseURL = gitRemote:
    let m = builtins.match "([a-z]*)://([^/]*)(/?.*)" gitRemote;
    in if m == null then throw "Could not parse ${opt.remote} as a url. Value: ${gitRemote}" else {
      scheme = lib.elemAt m 0;
      host = lib.elemAt m 1;
      path = lib.elemAt m 2;
    };

  remote = parseURL cfg.remote.url;

in
{
  imports = [
    ./git.nix
  ];
  options = {
    git.checkout = {
      remote.url = mkOption {
        type = types.str;
        description = ''
          The git remote URL. Currently only http/https URLs are supported.

          The current repo URL is available in [`herculesCI.repo.remoteHttpUrl`](https://flake.parts/options/hercules-ci-effects.html#opt-herculesCI.repo.remoteHttpUrl) or the metadata passed to the `herculesCI` function: [`primaryRepo.remoteHttpUrl`](https://docs.hercules-ci.com/hercules-ci-agent/evaluation/#params-herculesCI-primaryRepo-remoteHttpUrl).
        '';
        example = lib.literalExpression "primaryRepo.remoteHttpUrl";
      };
      remote.parsedUrl = mkOption {
        type = types.lazyAttrsOf types.str;
        description = ''
          Subject to change.

          `git.checkout.remote.url` parsed into some parts. This is an internal
          option; see implementation.
        '';
        internal = true;
      };
      forgeType = mkOption {
        type = types.str;
        description = ''
          The forge type according to Hercules CI.

          Valid values include `"github"` and `"gitlab"`, or you could forward this from [`herculesCI.repo.forgeType`](https://flake.parts/options/hercules-ci-effects.html#opt-herculesCI.repo.forgeType) (flake-parts) or the metadata passed to the `herculesCI` function: [`primaryRepo.forgeType`](https://docs.hercules-ci.com/hercules-ci-agent/evaluation/#params-herculesCI-primaryRepo-forgeType).
        '';
        example = lib.literalExpression "primaryRepo.forgeType";
      };
      tokenSecret = mkOption {
        type = types.str;
        description = ''
          Name of the secret that contains the git token.
        '';
        default = "token";
      };
      user = mkOption {
        type = types.str;
        description = ''
          User name for authentication with the git remote.
        '';
        default = "git";
      };
    };
  };
  config = {
    userSetupScript = ''
      echo "${remote.scheme}://${cfg.user}:$(readSecretString ${cfg.tokenSecret} .token)@${remote.host}${remote.path}" >>~/.git-credentials
      git config --global credential.helper store
    '';
    git.checkout.remote.parsedUrl = remote;
  };
}
