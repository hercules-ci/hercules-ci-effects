{ lib }:
let
  inherit (lib) types mkOption submodule;

  coercedToList = t: types.coercedTo t (x: [x]) (types.listOf t);

  option = mkOption {
    description = ''
      The time at which to schedule a job.

      Each subattribute represents an equality, all of which will hold at the next planned time. The time zone is UTC.

      The `minute` or `hour` attributes can be omitted, in which case Hercules CI will pick an arbitrary time for you.
      
      See the `when.*` options below for details.
    '';
    inherit type;
    default = { };
  };

  type = types.submodule module;

  module = {
    _file = ./when.nix;
    options = {
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
        type = types.nullOr (coercedToList (types.enum [ "Mon" "Tue" "Wed" "Thu" "Fri" "Sat" "Sun" ]));
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

in
{ inherit option type module; }
