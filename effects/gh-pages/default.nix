{
  pkgs,
  runIf,
  mkEffect
}:

let inherit (pkgs) lib;
    inherit (pkgs.lib) optionalString;
 in

{
  gh-pages,
  branchName ? "gh-pages",
  condition ? { ref, ... }: lib.elem ref ["refs/heads/main" "refs/heads/master"],
  committer ? {
    name = "Andrey Vlasov";
    email = "andreyvlasov+gh-pages-builder@mlabs.city";
  }
}:
{ primaryRepo, ... }:
{
  onPush.gh-pages.outputs.effects.default =
    runIf (condition primaryRepo) (
      mkEffect {
        buildInputs = with pkgs; [ openssh git ];
        secretsMap = {
          git = { type = "GitToken"; };
        };

        # Env variables
        inherit branchName;
        inherit (primaryRepo) owner remoteHttpUrl;
        githubHostKey = "github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==";
        ghPages = gh-pages;
        GIT_COMMITTER_NAME = committer.name;
        GIT_COMMITTER_EMAIL = committer.email;
        GIT_AUTHOR_NAME = committer.name;
        GIT_AUTHOR_EMAIL = committer.email;

        effectScript =
          ''
            set -e
            set -x
            TOKEN=`readSecretString git .token`
            ORIGIN=`echo $remoteHttpUrl | sed "s#://#://$owner:$TOKEN@#"`
            echo githubHostKey >> ~/.ssh/known_hosts
            cp -r --no-preserve=mode $ghPages ./gh-pages && cd gh-pages
            git init -b $branchName
            git remote add origin $ORIGIN
            git add .
            git commit -m "Deploy to $branchName"
            git push -f origin $branchName:$branchName
          '';
      }
    );
}
