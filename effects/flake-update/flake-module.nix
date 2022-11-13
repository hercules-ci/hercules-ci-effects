{ config, lib, withSystem, ... }:
let
  inherit (lib) mkOption types optionalAttrs;
  cfg = config.hercules-ci.flake-update;
in
{
  options = {
    hercules-ci.flake-update = {
      enable = lib.mkEnableOption "Scheduled flake update job";
      updateBranch = mkOption {
        type = types.str;
        default = "flake-update";
        example = "update";
        description = ''
          To which branch to push the updated flake lock.
        '';
      };
      when = mkOption {
        type = types.raw;
        description = ''
          See `herculesCI.onSchedule.<name>.when` for details.
        '';
      };
      effect.system = mkOption {
        type = types.str;
        default = config.defaultEffectSystem;
        defaultText = lib.literalExpression "config.defaultEffectSystem";
        example = "aarch64-linux";
        description = ''
          The [system](https://nixos.org/manual/nix/stable/command-ref/conf-file.html#conf-system) on which to run the flake update job.
        '';
      };
    };
  };
  config = {
    perSystem = perSystem@{ config, pkgs, hci-effects, ... }: {
      herculesCI = herculesCI@{ ... }: {
        onSchedule.effects.flake-update =
          hci-effects.flakeUpdate {
            gitRemote = herculesCI.config.repo.remoteHttpUrl;
            user = "x-access-token";
            inherit (cfg) updateBranch;
          };
      };
    };
    herculesCI = herculesCI@{ config, ... }: optionalAttrs (cfg.enable) {
      onSchedule.flake-update = {
        inherit (cfg) when;
        effects.flake-update.enable = true;
      };
    };
  };
}
