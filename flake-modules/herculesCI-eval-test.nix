{ inputs }:
rec {
  inherit (inputs) flake-parts;

  example1 =
    flake-parts.lib.mkFlake { self = { }; }
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
      });

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

    ok;

}

