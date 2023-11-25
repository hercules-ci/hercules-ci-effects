args@
{ inputs ? hercules-ci-effects.inputs
, hercules-ci-effects ? if args?inputs then inputs.self else builtins.getFlake "git+file://${toString ./../..}"
}:
let
  testSupport = import ../../lib/testSupport.nix args;
in
rec {
  inherit (inputs) flake-parts nixpkgs;
  inherit (nixpkgs) lib;
  inherit (testSupport) callFlakeOutputs;

  fakeRepoBranch = {
    branch = "main";
    ref = "refs/heads/main";
    rev = "deadbeef";
    shortRev = "deadbe";
    tag = null;
    remoteHttpUrl = "https://git.forge/repo.git";
  };
  fakeRepoTag = {
    branch = null;
    ref = "refs/heads/main";
    rev = "deadbeef";
    shortRev = "deadbe";
    tag = "1.0";
    remoteHttpUrl = "https://git.forge/repo.git";
  };
  fakeHerculesCI = repo: {
    primaryRepo = repo;
    inherit (repo) branch ref tag rev shortRev remoteHttpUrl;
  };

  basicUpdateOutputs =
    callFlakeOutputs (inputs:
      flake-parts.lib.mkFlake { inherit inputs; }
      ({ ... }: {
        imports = [
          ../../flake-module.nix
        ];
        systems = ["x86_64-linux"];
        hercules-ci.flake-update.enable = true;
        hercules-ci.flake-update.when = { hour = 23; minute = 59; };
      })
    );
  basicUpdateHerculesCI = basicUpdateOutputs.herculesCI (fakeHerculesCI fakeRepoBranch);
  basicUpdateConfig = basicUpdateHerculesCI.onSchedule.flake-update.outputs.effects.flake-update.config;

  subflakeUpdateOutputs =
    callFlakeOutputs (inputs:
      flake-parts.lib.mkFlake { inherit inputs; }
      ({ ... }: {
        imports = [
          ../../flake-module.nix
        ];
        systems = ["x86_64-linux"];
        hercules-ci.flake-update.enable = true;
        hercules-ci.flake-update.when = { hour = 23; minute = 59; };
        hercules-ci.flake-update.flakes = { "subflake" = { inputs = ["nixpkgs"]; }; };
      })
    );
  subflakeUpdateHerculesCI = subflakeUpdateOutputs.herculesCI (fakeHerculesCI fakeRepoBranch);
  subflakeUpdateConfig = subflakeUpdateHerculesCI.onSchedule.flake-update.outputs.effects.flake-update.config;

  matches = regex: string: builtins.match regex string != null;
  contains = substring: matches ".*${lib.escapeRegex substring}.*";

  tests = ok:
    
    assert basicUpdateHerculesCI.onSchedule.flake-update.when ==
      { dayOfMonth = null; dayOfWeek = null; hour = [ 23 ]; minute = 59; };

    assert contains "cd 'subflake'" subflakeUpdateConfig.git.update.script;
    # The default (flake at root) is overridden by the user definition. Potentially not future proof because it could match some other './.' substring.
    assert ! contains "cd '.'" subflakeUpdateConfig.git.update.script;
    assert contains "cd '.'" basicUpdateConfig.git.update.script;

    assert contains "--update-input nixpkgs" subflakeUpdateConfig.git.update.script;

    ok;

}

