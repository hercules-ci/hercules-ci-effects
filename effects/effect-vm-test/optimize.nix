{ hostPkgs, ... }: {
  config = {
    defaults = {
      documentation.enable = false;
      # environment.noXlibs = true;
    };
  };
}
