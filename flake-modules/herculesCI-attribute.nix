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
        default = throw "repo.remoteHttpUrl requires hercules-ci-agent >=0.9.8. If you run hci effect run, make sure your repository remote has an http(s) URL.";
      };
      remoteSshUrl = mkOption {
        type = types.str;
        readOnly = true;
        description = ''
          SSH url for cloning the repository.

          _Since hercules-ci-agent 0.9.8_
        '';
        defaultText = lib.literalMD "";
        default = throw "repo.remoteHttpUrl requires hercules-ci-agent >=0.9.8. If you run hci effect run, make sure your repository remote has an ssh URL.";
      };
      webUrl = mkOption {
        type = types.str;
        readOnly = true;
        description = ''
          A URL to open the repository in the browser.

          _Since hercules-ci-agent 0.9.8_
        '';
        defaultText = lib.literalMD "";
        default = throw "repo.webUrl requires hercules-ci-agent >=0.9.8. If you run hci effect run, make sure your repository remote has an http URL.";
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
        default = throw "repo.forgeType requires hercules-ci-agent >=0.9.8.";
      };
      owner = mkOption {
        type = types.str;
        description = ''
          The owner of the repository.

          _Since hercules-ci-agent 0.9.8_
        '';
        readOnly = true;
        defaultText = lib.literalMD "";
        default = throw "repo.owner requires hercules-ci-agent >=0.9.8.";
      };
      name = mkOption {
        type = types.str;
        description = ''
          The name of the repository.

          _Since hercules-ci-agent 0.9.8_
        '';
        readOnly = true;
        defaultText = lib.literalMD "";
        default = throw "repo.name requires hercules-ci-agent >=0.9.8.";
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
      when = {
        minute = mkOption {
          type = types.nullOr (types.ints.between 0 59);
          default = null;
          description = ''
            An optional integer representing the minute mark at which a job should be created.
            
            The default value `null` represents an arbitrary minute.
          '';
        };
        hour = mkOption {
          type = types.nullOr (coercedToList (types.ints.between 0 23));
          default = null;
          description = ''
            An optional integer representing the hours at which a job should be created.
            
            The default value `null` represents an arbitrary hour.
          '';
        };
        dayOfWeek = mkOption {
          type = types.nullOr (types.enum ["Mon" "Tue" "Wed" "Thu" "Fri" "Sat" "Sun"]);
          default = null;
          description = ''
            An optional list of week days during which to create a job.

            The default value `null` represents all days.
          '';
        };
        dayOfMonth = mkOption {
          type = types.nullOr (coercedToList (types.ints.between 0 31));
          default = null;
          description = ''
            An optional list of day of the month during which to create a job.

            The default value `null` represents all days.
          '';
        };
      };
    };
  };

  coercedToList = t: types.coercedTo t (x: [x]) (types.listOf t);

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
    };
    config = {
      onPush.default.outputs =
        default-hci-for-flake.flakeToOutputs
          self
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

        Regarding the implementation: Hercules CI offers a bit more information than flakes by itself, and does so by calling the `herculesCI` attribute on the flake.
        The purpose of the top-level `herculesCI` option in the flake-parts module is to facilitate define this function using declared options.
      '';
    };
  };

  config = {
    flake.herculesCI = {
      # These are lazy errors in order to allow some exploration in nix repl.
      # hci repl: https://github.com/hercules-ci/hercules-ci-agent/issues/459
      herculesCI ? throw "`<flake>.outputs.herculesCI` requires an `herculesCI` argument.",
      primaryRepo ? throw "`<flake>.outputs.primaryRepo` requires a `primaryRepo` argument.",
      ... }:
      let
        paramModule = {
          _file = "herculesCI parameters";
          config = {
            # Filter out values which are unavailable and therefore null.
            # e.g. hci effect run may not support owner and name.
            # Always be careful when filtering, because it's not as lazy as you'd like.
            # Shouldn't be a problem here though.
            repo = lib.filterAttrs (k: v: v != null) {
              inherit (primaryRepo) ref branch tag rev shortRev;
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