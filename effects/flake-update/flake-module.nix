{ config, lib, withSystem, ... }:
let
  inherit (lib) mkOption types optionalAttrs;
  cfg = config.hercules-ci.flake-update;
in
{
  options.hercules-ci.flake-update = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether to create a scheduled flake update job.

        For a complete example, see [the hercules-ci-effects documentation on `hercules-ci.flake-update`](https://docs.hercules-ci.com/hercules-ci-effects/reference/flake-parts/flake-update/).

        _Requires hercules-ci-agent 0.9.8 or newer._
      '';
    };

    updateBranch = mkOption {
      type = types.str;
      default = "flake-update";
      example = "update";
      description = ''
        To which branch to push the updated `flake lock`.
      '';
    };

    forgeType = mkOption {
      type = types.str;
      default = "github";
      example = "gitlab";
      description = ''
        The type of Git server commited to.
      '';
    };

    createPullRequest = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to create a pull request for the updated `flake.lock`.
      '';
    };

    when = mkOption {
      type = types.raw;
      description = ''
        See [`herculesCI.onSchedule.<name>.when`](#opt-herculesCI.onSchedule._name_.when) for details.
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

  config = {
    herculesCI = herculesCI@{ config, ... }: optionalAttrs (cfg.enable) {
      onSchedule.flake-update = {
        inherit (cfg) when;
        outputs = {
          effects = {
            flake-update = withSystem cfg.effect.system ({ config, pkgs, hci-effects, ... }:
              hci-effects.flakeUpdate {
                gitRemote = herculesCI.config.repo.remoteHttpUrl;
                user = "x-access-token";
                inherit (cfg) updateBranch forgeType createPullRequest;
              }
            );
          };
        };
      };
    };
  };
}
