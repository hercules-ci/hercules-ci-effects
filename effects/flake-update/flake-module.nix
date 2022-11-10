{ config, lib, withSystem, ... }:
let
  inherit (lib) mkOption types optionalAttrs;
  cfg = config.flake-update;
in
{
  options = {
    flake-update = {
      enable = lib.mkEnableOption "Scheduled flake update job";
      updateBranch = mkOption {
        type = types.str;
        default = "flake-update";
        example = "update";
        description = lib.mdDoc ''
          To which branch to push the updated flake lock.
        '';
      };
      effect.system = mkOption {
        type = types.str;
        default = config.defaultEffectSystem;
        defaultText = lib.literalExpression "config.defaultEffectSystem";
        example = "aarch64-linux";
        description = lib.mdDoc ''
          The [system](https://nixos.org/manual/nix/stable/command-ref/conf-file.html#conf-system) on which to run the flake update job.
        '';
      };
    };
  };
  config = {
    herculesCI = herculesCI@{ config, ... }: optionalAttrs (cfg.enable) {
      onSchedule.flake-update = {
        outputs = {
          effects = {
            flake-update = withSystem cfg.effect.system ({ config, pkgs, hci-effects, ... }:
              hci-effects.flakeUpdate {
                gitRemote = herculesCI.config.repo.remoteHttpUrl;
                user = "x-access-token";
                inherit (cfg) updateBranch;
              }
            );
          };
        };
      };
    };
  };
}