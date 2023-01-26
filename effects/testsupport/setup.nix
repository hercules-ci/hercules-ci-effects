{ lib, config, ... }:
let
  inherit (lib)
    concatStrings
    mapAttrsToList
    mkOption
    types
    ;
in
{

  options = {
    setupScript = mkOption {
      type = types.lines;
      description = ''
        Python code that runs before the main test.

        Variables defined by this code will be available in the test.
      '';
      default = "";
    };
    testCases = mkOption {
      type = types.str;
      description = ''
        The test cases. See `testScript`.
      '';
    };
  };

  config = {
    testScript = ''
      start_all();

      ${config.setupScript}

      ### SETUP COMPLETE ###

      ${config.testCases}
    '';
  };

}
