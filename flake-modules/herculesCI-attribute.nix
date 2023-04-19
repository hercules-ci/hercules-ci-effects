flakeParts@{ lib, config, self, ... }:
let
  inherit (lib)
    types
    mkOption
    ;

  default-hci-for-flake = import ../vendor/hercules-ci-agent/default-herculesCI-for-flake.nix;
  inherit (import ./derivationTree-type.nix { inherit lib; }) derivationTree;

  repoModule = {
    options = {
      ref = mkOption {
        type = types.str;
        readOnly = true;
        description = ''
          The git "ref" of the checkout.
        '';
        example = "refs/heads/main";
      };
      branch = mkOption {
        type = types.nullOr types.str;
        readOnly = true;
        description = ''
          The branch of the checkout. `null` when not on a branch; e.g. when on a tag.
        '';
        example = "main";
      };
      tag = mkOption {
        type = types.nullOr types.str;
        readOnly = true;
        description = ''
          The tag of the checkout. `null` when not on a tag; e.g. when on a branch.
        '';
        example = "1.0";
      };
      rev = mkOption {
        type = types.str;
        readOnly = true;
        description = ''
          The git revision, also known as the commit hash.
        '';
        example = "17ae1f614017447a983c34bb046892b3c571df52";
      };
      shortRev = mkOption {
        type = types.str;
        readOnly = true;
        description = ''
          An abbreviated `rev`.
        '';
        example = "17ae1f6";
      };
      remoteHttpUrl = mkOption {
        type = types.str;
        readOnly = true;
        description = ''
          HTTP url for cloning the repository.

          _Since hercules-ci-agent 0.9.8_
        '';
        defaultText = lib.literalMD "";
      };
      remoteSshUrl = mkOption {
        type = types.str;
        readOnly = true;
        description = ''
          SSH url for cloning the repository.

          _Since hercules-ci-agent 0.9.8_
        '';
        defaultText = lib.literalMD "";
      };
      webUrl = mkOption {
        type = types.str;
        readOnly = true;
        description = ''
          A URL to open the repository in the browser.

          _Since hercules-ci-agent 0.9.8_
        '';
        defaultText = lib.literalMD "";
      };
      forgeType = mkOption {
        type = types.str;
        readOnly = true;
        description = ''
          What forge implementation hosts the repository.

          E.g. "github" or "gitlab"

          _Since hercules-ci-agent 0.9.8_
        '';
        example = "github";
        defaultText = lib.literalMD "";
      };
      owner = mkOption {
        type = types.str;
        description = ''
          The owner of the repository.

          _Since hercules-ci-agent 0.9.8_
        '';
        readOnly = true;
        defaultText = lib.literalMD "";
      };
      name = mkOption {
        type = types.str;
        description = ''
          The name of the repository.

          _Since hercules-ci-agent 0.9.8_
        '';
        readOnly = true;
        defaultText = lib.literalMD "";
      };
    };
  };

  outputsModule = { ... }: {
    options = {
      outputs = mkOption {
        type = derivationTree;
        description = ''
          A collection of builds and effects. These may be nested recursively into attribute sets.

          Hercules CI's traversal of nested sets can be cancelled with `lib.dontRecurseIntoAttrs`.

          See the parent option for details about when the job runs.
        '';
      };
    };
  };

  onPushModule = { ... }: {
    imports = [ outputsModule ];
  };

  onScheduleModule = { ... }: {
    imports = [ outputsModule ];
    options = {
      when = (import ./types/when.nix { inherit lib; }).option;
    };
  };

  herculesCIModule = { config, ... }: {
    options = {
      repo = mkOption {
        type = types.submodule repoModule;
        readOnly = true;
        description = ''
          The repository and checkout metadata of the current checkout, provided by Hercules CI.
          These options are read-only.

          You may read options by querying the `config` module argument.
        '';
      };
      out = mkOption {
        type = types.lazyAttrsOf types.raw;
        internal = true;
        description = ''
          The return value of the `herculesCI` function in the flake.
          All attributes in this return value should be represented by options
          that write to this internal option.
        '';
      };
      onPush = mkOption {
        type = types.lazyAttrsOf (types.submoduleWith { modules = [ onPushModule ]; });
        description = ''
          This declares what to do when a Git ref is updated, such as when you push a commit or after you merge a pull request.

          By default `onPush.default` defines a job that builds the known flake output attributes.
          It can be disabled by setting `onPush.default.enable = false;`.

          The name of the job (from `onPush.<name>`) will be used as part of the commit status of the resulting job.
        '';
        default = {};
      };
      onSchedule = mkOption {
        type = types.lazyAttrsOf (types.submoduleWith { modules = [ onScheduleModule ]; });
        description = ''
          _Since hercules-ci-agent 0.9.8_

          Behaves similar to onPush, but is responsible for jobs that respond to the passing of time rather than to a git push or equivalent.
        '';
        default = {};
      };
      ciSystems = mkOption {
        type = types.listOf types.str;
        default = flakeParts.config.systems;
        defaultText = lib.literalExpression "config.systems  # from flake parts";
        description = ''
          Flake systems for which to generate attributes in `herculesCI.onPush.default.outputs`.
        '';
      };
      flakeForOnPushDefault = mkOption {
        type = types.raw;
        default = self;
        defaultText = lib.literalExpression "self";
        description = ''
          The flake to use when automatically deriving the onPush.default job.

          If you use mkFlake (you should), you have no reason to set this.
          This is primarily an extension point for `mkHerculesCI`.
        '';
        internal = true;
      };
    };
    config = {
      onPush.default.outputs =
        default-hci-for-flake.flakeToOutputs
          config.flakeForOnPushDefault
          { ciSystems = lib.genAttrs config.ciSystems (system: {}); };
      out = {
        inherit (config) onPush onSchedule ciSystems;
      };
    };
  };

in
{

  options = {
    herculesCI = mkOption {
      type = types.deferredModuleWith { staticModules = [ herculesCIModule ]; };
      description = ''
        Hercules CI environment and configuration. See the sub-options for details.

        This module represents a function. Hercules CI calls this function to provide expressions in the flake with extra information, such as repository and job metadata.

        While this attribute feels a lot like a submodule, it can not be queried by definitions outside of `herculesCI`. This is required by the design of flakes: evaluation of the standard flake attribute values is hermetic.

        Data that is unique to Hercules CI (as opposed to the flake itself) is provided by in the sub-options of `herculesCI`. This is syntactically different from the [native `herculesCI` attribute interface](https://docs.hercules-ci.com/hercules-ci-agent/evaluation#params-herculesCI). For example, instead of `{ primaryRepo, ... }: ... primaryRepo.ref`, you would write `{ config, ... }: ... config.repo.ref`.

        See e.g. [`ref`](#opt-herculesCI.repo.ref).
      '';
    };
  };

  config = {
    flake.herculesCI = {
      # These are lazy errors in order to allow some exploration in nix repl.
      # hci repl: https://github.com/hercules-ci/hercules-ci-agent/issues/459
      herculesCI ? throw "`<flake>.outputs.herculesCI` requires an `herculesCI` argument.",
      primaryRepo ? throw "`<flake>.outputs.herculesCI` requires a `primaryRepo` argument.",
      ... }:
      let
        paramModule = {
          _file = "herculesCI parameters";
          config = {
            # Filter out values which are unavailable and therefore null.
            # e.g. hci effect run may not support owner and name.
            repo = {
              ref = primaryRepo.ref;
              branch = primaryRepo.branch or null;
              tag = primaryRepo.tag or null;
              rev = primaryRepo.rev;
              shortRev = primaryRepo.shortRev;
            } // lib.filterAttrs (k: v: v != null) {
              remoteHttpUrl = primaryRepo.remoteHttpUrl or null;
              remoteSshUrl = primaryRepo.remoteSshUrl or null;
              webUrl = primaryRepo.webUrl or null;
              forgeType = primaryRepo.forgeType or null;
              owner = primaryRepo.owner or null;
              name = primaryRepo.name or null;
            };
          };
        };
        eval = lib.evalModules { modules = [ paramModule config.herculesCI ]; };
      in
        eval.config.out;
  };

}