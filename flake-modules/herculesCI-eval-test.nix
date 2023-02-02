args@
{ inputs ? hercules-ci-effects.inputs
, hercules-ci-effects ? if args?inputs then inputs.self else builtins.getFlake "git+file://${toString ./..}"
}:
let
  testSupport = import ../lib/testSupport.nix args;
in
rec {
  inherit (inputs) flake-parts;
  inherit (testSupport) callFlakeOutputs;

  emptyFlake = callFlakeOutputs (inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        ../flake-module.nix
      ];
      systems = [ "x86_64-linux" ];
    }
  );

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

  example1 =
    callFlakeOutputs (inputs:
      flake-parts.lib.mkFlake { inherit inputs; }
      ({ ... }: {
        imports = [
          ../flake-module.nix
        ];
        herculesCI.onSchedule.scheduledJob1.when = {
          dayOfMonth = [ 1 3 5 7 31 ];
          dayOfWeek = [ "Mon" "Wed" "Fri" ];
          hour = [ 0 1 23 ];
          minute = 32;
        };
        herculesCI.onSchedule.scheduledJob2.when = {
          dayOfMonth = 31;
          dayOfWeek = "Fri";
          hour = 23;
          minute = 59;
        };
        herculesCI.onSchedule.scheduledJob3 = { };
      })
    );

  tests = ok:

    assert (example1.herculesCI { }).onSchedule.scheduledJob1.when ==
      {
        dayOfMonth = [ 1 3 5 7 31 ];
        dayOfWeek = [ "Mon" "Wed" "Fri" ];
        hour = [ 0 1 23 ];
        minute = 32;
      };

    assert (example1.herculesCI { }).onSchedule.scheduledJob2.when ==
      {
        dayOfMonth = [ 31 ];
        dayOfWeek = [ "Fri" ];
        hour = [ 23 ];
        minute = 59;
      };

    assert (example1.herculesCI { }).onSchedule.scheduledJob3.when ==
      {
        dayOfMonth = null;
        dayOfWeek = null;
        hour = null;
        minute = null;
      };

    assert (emptyFlake.herculesCI (fakeHerculesCI fakeRepoBranch))._debug.repo.branch == "main";
    assert (emptyFlake.herculesCI (fakeHerculesCI fakeRepoBranch))._debug.repo.tag == null;

    assert (emptyFlake.herculesCI (fakeHerculesCI fakeRepoTag))._debug.repo.branch == null;
    assert (emptyFlake.herculesCI (fakeHerculesCI fakeRepoTag))._debug.repo.tag == "1.0";

    ok;

}

