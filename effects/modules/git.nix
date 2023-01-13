{ config, lib, pkgs, ... }:
let
  inherit (lib)
    mkOption
    types
    ;
in
{
  config = {
    inputs = [
      pkgs.git
    ];

    env = {
      EMAIL = "hercules-ci[bot]@users.noreply.github.com";
      GIT_AUTHOR_NAME = "Hercules CI Effects";
      GIT_COMMITTER_NAME = "Hercules CI Effects";
      PAGER = "cat";
    };
  };
}
