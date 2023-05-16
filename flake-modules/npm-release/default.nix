{ config, lib, options, withSystem, ... }:
let
  inherit (lib) mkOption mkOptionType types;
in
{
  options =
    {
      hercules-ci.npm-release = {
        condition = mkOption {
          type = types.functionTo types.bool;
          description = ''
            Condition under which a release is going to be pushed.
            This is a function accepting [HerculesCI parameters](https://docs.hercules-ci.com/hercules-ci-agent/evaluation#params-herculesCI)
            and returning boolean.
            By default, pushing happens if a tag is present.
          '';
          default = { tag, ... }: tag != null;
          defaultText = lib.literalExpression ''
            { tag, ... }: tag != null
          '';
        };
        package = mkOption {
          type = types.package;
          default = null;
          description = ''
            Path or derivation which produces a path containing what is going to be pushed.
            Must contain a `package.json` file which specifies in a `files` field what files
            are going to be pushed.
          '';
        };
      };
    };

  config =
    let
      inherit (lib) mkIf mkMerge;
      inherit (config) defaultEffectSystem;

      cfg = config.hercules-ci.npm-release;
      opt = options.hercules-ci.npm-release;
      enable = cfg.package != null;
    in
    {
      herculesCI = mkIf enable (herculesCI@{ config, ... }:
        let
          npm-publish-script = pkgs: pkgs.writeShellApplication {
            name = "npm-publish";
            runtimeInputs = with pkgs; [ nodePackages.npm ];
            text = ''
              cd ${cfg.package}
              export NODE_AUTH_TOKEN=$token
              echo here
              echo "$NODE_AUTH_TOKEN"
              npm publish
            '';
          };
          deploy = withSystem defaultEffectSystem ({ hci-effects, pkgs, ... }:
            hci-effects.modularEffect {
              imports = [
                ../../effects/modules/git-auth-gh.nix
              ];
              secretsMap = {
                token = { type = "GitToken"; };
              };
              git.checkout = {
                remote.url = config.repo.remoteHttpUrl;
                forgeType = config.repo.forgeType;
              };
              effectScript = lib.getExe (npm-publish-script pkgs);
            }
          );
        in
        {
          onPush.default.outputs.effects.npm-release =
            lib.optionalAttrs
              (cfg.condition herculesCI.config.repo)
              deploy;
        }
      );
    };
}
