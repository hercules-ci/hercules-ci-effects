{ config, lib, self, withSystem, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.hercules-ci.cargo-publish;
  inherit (config) defaultEffectSystem;
in
{
  options = {
    hercules-ci.cargo-publish = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable the cargo publish effect.

          This will perform a [`cargo publish`](https://doc.rust-lang.org/cargo/commands/cargo-publish.html) [`--dry-run`](https://doc.rust-lang.org/cargo/commands/cargo-publish.html#publish-options) on every branch push, and a proper `publish` when a tag is pushed.

          Example usage:
          ```nix
          hercules-ci.cargo-publish.enable = true;
          hercules-ci.cargo-publish.secretName = "crates.io";
          ```

          If you need more flexibility, you can use the [`cargoPublish`](https://docs.hercules-ci.com/hercules-ci-effects/reference/nix-functions/cargopublish) effect function directly.
        '';
      };
      secretName = mkOption {
        type = types.str;
        default = null;
        description = ''
          The name of the secret containing the token for the registry.
        '';
      };
      registryURL = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          The URL of the custom registry to use for publishing.
        '';
      };
      extraPublishArgs = mkOption {
        type = types.listOf types.str;
        default = [];
        description = ''
          Extra arguments to pass to `cargo publish`.
        '';
      };
      src = mkOption {
        type = types.path;
        default = self.outPath;
        defaultText = lib.literalExpression ''self.outPath'';
        description = ''
          The path to the source code to publish.
        '';
      };
      packageName = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          The name of the package to publish. If set, it will be checked that the tag matches the package version.
        '';
      };
    };
  };
  config = lib.mkIf (config.hercules-ci.cargo-publish.enable) {
    herculesCI = { config, ... }: {
      onPush.default = {
        outputs = {
          effects = {
            cargoPublish = withSystem defaultEffectSystem ({ hci-effects, pkgs, ... }:
              hci-effects.cargoPublish {
                inherit (cfg) secretName registryURL src;
                dryRun = config.repo.tag == null;
                assertVersions = lib.optionalAttrs (cfg.packageName != null && config.repo.tag != null) {
                  ${cfg.packageName} = config.repo.tag;
                };
                extraPublishArgs = cfg.extraPublishArgs ++ lib.optionals (cfg.packageName != null) [
                  "--package" cfg.packageName
                ];
              }
            );
          };
        };
      };
    };
  };
}