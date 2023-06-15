{ effectVMTest, hci-effects }:

let

  baseUpdate = {
    imports = [ ../git-update.nix ];
    git.checkout.remote.url = "http://gitea:3000/test/repo";
    git.checkout.forgeType = "gitea";
    git.checkout.user = "test";

    git.update.branch = "update";
    git.update.pullRequest.enable = false;

    secretsMap.token = { type = "GitToken"; };

    name = "update";
  };

in
effectVMTest {
  imports = [
    ../../testsupport/dns.nix
    ../../testsupport/gitea.nix
    ../../testsupport/setup.nix
  ];
  name = "flake-update";
  effects = {
    update = hci-effects.modularEffect {
      imports = [ baseUpdate ];
      git.update.script = ''
        echo updated >> file
        git add file
        git commit -m update
      '';
    };
    update-uncommitted = hci-effects.modularEffect {
      imports = [ baseUpdate ];
      git.update.script = ''
        echo updated >> file
        git add file
      '';
    };
    update-unstaged = hci-effects.modularEffect {
      imports = [ baseUpdate ];
      git.update.script = ''
        echo updated >> file
      '';
    };
    update-no-commit = hci-effects.modularEffect {
      imports = [ baseUpdate ];
      git.update.script = "";
    };
  };

  testCases = ''
    token = gitea_admin_token

    repo = client.succeed("""
      curl -v --fail -X POST http://gitea:3000/api/v1/user/repos \
        -H 'Accept: application/json' -H 'Content-Type: application/json' \
        """ + f"-H 'Authorization: token {token}'" + """ \
        -d '{"name":"repo", "private":true}'
    """)
    print(repo)

    client.succeed("""
    (
      git clone http://gitea:3000/test/repo.git
      cd repo
      echo init > file
      git add file
      git commit -m 'file: init'
      git push
    ) 1>&2
    """)

    agent.succeed(f"echo {gitea_admin_password} | effect-update")

    client.succeed("""
      (
        set -x
        cd repo
        git fetch origin
        git checkout origin/update
        grep updated <file
      ) 1>&2
    """).rstrip()


    # repoName: name of the repo checkout directory on `client`
    def getRev():
      return client.succeed("""
        (
          cd repo
          git fetch origin
          git checkout origin/update
          git rev-parse HEAD
        )
      """).rstrip()

    repo_update_rev = getRev()

    with subtest("Not committing is ok"):
      r1 = getRev()
      agent.succeed(f"echo {gitea_admin_password} | effect-update-no-commit")
      assert getRev() == r1

    with subtest("Fail if work tree has unstaged changes"):
      r1 = getRev()
      agent.succeed(f"echo {gitea_admin_password} | (set -x; if effect-update-unstaged; then false; else [[ $? == 1 ]]; fi)")
      assert getRev() == r1

    with subtest("Fail if work tree has uncommitted changes"):
      r1 = getRev()
      agent.succeed(f"echo {gitea_admin_password} | (set -x; if effect-update-uncommitted; then false; else [[ $? == 1 ]]; fi)")
      assert getRev() == r1

  '';
}
