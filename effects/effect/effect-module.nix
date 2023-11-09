{ config, lib, hci-effects, pkgs, ... }:
let
  inherit (lib)
    filterAttrs
    literalExpression
    mkOption
    optionalAttrs
    types
    ;

  secretType = types.either types.str (types.submodule secretModule);

  secretModule = {
    options = {
      type = mkOption {
        type = types.enum [ "GitToken" ];
        description = ''
          Makes the type of secret explicit. This may be extended in the future.
        '';
      };
    };
  };

in
{
  options = {

    effectScript = mkOption {
      type = types.str;
      description = ''
        Bash statements that form the essence of the effect.
      '';
      default = "";
    };

    userSetupScript = mkOption {
      type = types.lines;
      description = ''
        Bash statements to set up user configuration files. Unlike the Nix build sandbox, Effects can make use of a home directory.

        Various bash functions are available, such as [writeSSHKey](https://docs.hercules-ci.com/hercules-ci-effects/reference/bash-functions/writeSSHKey/).
      '';
      default = "";
    };

    inputs = mkOption {
      type = types.listOf types.package;
      description = ''
        A list of packages that are added to PATH. This behaves like [`nativeBuildInputs` in `mkDerivation`](https://nixos.org/manual/nixpkgs/stable/#var-stdenv-nativeBuildInputs).
      '';
      default = [ ];
    };

    secretsMap = mkOption {
      type = types.lazyAttrsOf secretType;
      description = ''
        An attribute set of strings that select secrets from the agent’s secrets.json. For example

        The attribute values are converted by retrieving their values and passed to the effect as the JSON file in `$HERCULES_CI_SECRETS_JSON`.

        See [Hercules CI Agent Secrets](https://docs.hercules-ci.com/hercules-ci-agent/effects/#_secrets).
      '';
      example = literalExpression ''
        {
          # simple string means look up in secrets.json on the agent
          "ssh" = "default-ssh";
          # GitToken secrets are provided by Hercules CI backend
          "git" = { type = "GitToken"; };
        }
      '';
      default = { };
    };

    src = mkOption {
      type = types.nullOr types.path;
      description = ''
        A source to be unpacked by the `stdenv` unpack hook, like `mkDerivation` would.
      '';
      default = null;
      example = ''
        lib.cleanSourceWith { path = ./.; filter = path: type: f path type; }
      '';
    };

    getStateScript = mkOption {
      description = ''
        Bash statements for retrieving deployment state ahead of a deployment.

        Stateless deployments do not need this.
      '';
      type = types.lines;
      default = "";
    };

    putStateScript = mkOption {
      description = ''
        Bash statements for saving the deployment state after a deployment.

        These will also be run when the `effectScript` fails.
      '';
      type = types.lines;
      default = "";
    };

    env = mkOption {
      description = ''
        The initial environment variables to set in the effect sandbox.
      '';
      default = { };
    };

    /* Semi-internal options */

    effectDerivationArgs = mkOption {
      type = types.lazyAttrsOf types.unspecified;
      description = ''
        The arguments to the `mkEffect` function, producing `effectDerivation`.

        Generally you won't have to set these, as they are represented by other options, with the added benefit of accurate types and support for the merging of definitions.
      '';
    };

    effectDerivation = mkOption {
      readOnly = true;
      description = ''
        The final representation of the effect.
      '';
      type = types.package;
    };

    name = mkOption {
      type = types.nullOr types.str;
      description = ''
        Optional. Allows customization of the name of the effect derivation produced.

        Generally the attribute name where the effect is put is more relevant.
      '';
      default = null;
    };

    extraAttributes = mkOption {
      description = ''
        Attributes to add to the returned effect. These only exist at the expression level and do not become part of the executable effect.

        This is similar to `passthru` in `mkDerivation`.
      '';
      default = { };
      type = types.submodule {
        freeformType = types.attrsOf types.raw;
        options = {
          # Is this a good idea? Needs integration.
          # tests = mkOption {
          #   type = types.lazyAttrsOf types.package;
          #   description = ''
          #     Tests
          #   '';
          #   default = { };
          # };
        };
      };
    };

  };
  config = {
    effectDerivation = hci-effects.mkEffect config.effectDerivationArgs;
    effectDerivationArgs = {
      inherit (config)
        effectScript
        userSetupScript
        inputs
        secretsMap
        getStateScript
        putStateScript
        ;
      passthru = config.extraAttributes;
    }
    // filterAttrs (k: v: v != null) {
      # Attributes that are omitted when null
      inherit (config)
        src
        name
        ;
    }
    // config.env # TODO warn about collisions
    ;

    extraAttributes.tests.buildable =
      (config.effectDerivation.overrideAttrs (o: { isEffect = false; })).inputDerivation;
    extraAttributes.config = config;
  };
}
