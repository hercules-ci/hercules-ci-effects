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
  imports = [ ./git.nix ];
  options = {
    git.checkout = {
      remote.url = mkOption {
        type = types.str;
        description = ''
          The git remote url. Currently only http/https URLs are supported.
        '';
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
      set -x
      echo "${remote.scheme}://${cfg.user}:$(readSecretString ${cfg.tokenSecret} .token)@${remote.host}${remote.path}" >>~/.git-credentials
      git config --global credential.helper store
    '';
  };
}
