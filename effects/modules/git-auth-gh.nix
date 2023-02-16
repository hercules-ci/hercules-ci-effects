{ config, lib, options, pkgs, ... }:
let
  inherit (lib)
    mkOption
    types
    ;

  cfg = config.programs.gh;
in
{
  imports = [
    ./git-auth.nix
  ];

  options = {
    programs.gh.enable = lib.mkOption {
      description = ''
        Whether to enable GitHub's `gh` command.
      '';
      default = config.git.checkout.forgeType == "github";
      defaultText = lib.literalExpression ''
        config.git.checkout.forgeType == "github"
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    userSetupScript = ''
      mkdir -p ~/.config/gh
      { echo "${config.git.checkout.remote.parsedUrl.host}:"
        echo "  oauth_token: $(readSecretString ${config.git.checkout.tokenSecret} .token)"
      } >~/.config/gh/hosts.yml
      mkdir -p ~/.config/nix
      echo "access-tokens = ${config.git.checkout.remote.parsedUrl.host}=$(readSecretString ${config.git.checkout.tokenSecret} .token)" \
        >>~/.config/nix/nix.conf
    '';
    inputs = [
      pkgs.gh
    ];
  };
}
