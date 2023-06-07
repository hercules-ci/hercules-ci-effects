{ effectVMTest, hci-effects }:

let

in
effectVMTest {
  imports = [
    ../testsupport/dns.nix
    ../testsupport/gitea.nix
    ../testsupport/setup.nix
  ];
  name = "flake-update";
  effects = {
    update = hci-effects.flakeUpdate {
      gitRemote = "http://gitea:3000/test/repo";
      user = "test";
      forgeType = "gitea";
      createPullRequest = false; # not supported
    };
    update-no-pr-body = hci-effects.flakeUpdate {
      gitRemote = "http://gitea:3000/test/repo";
      user = "test";
      forgeType = "gitea";
      createPullRequest = false; # TODO: should be `true`! Test case is almost useless now, except for evaluation
      pullRequestBody = null;
      # TODO add test case for non-empty body
      # TODO add test case for empty body
    };
    update-dep2input = hci-effects.flakeUpdate {
      gitRemote = "http://gitea:3000/test/repo";
      user = "test";
      forgeType = "gitea";
      createPullRequest = false;
      commitSummary = "Update dep2input with custom message";
      inputs = ["dep2input"];
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

    dep = client.succeed("""
      curl -v --fail -X POST http://gitea:3000/api/v1/user/repos \
        -H 'Accept: application/json' -H 'Content-Type: application/json' \
        """ + f"-H 'Authorization: token {token}'" + """ \
        -d '{"name":"dep", "private":true}'
    """)
    print(dep)

    dep2 = client.succeed("""
      curl -v --fail -X POST http://gitea:3000/api/v1/user/repos \
        -H 'Accept: application/json' -H 'Content-Type: application/json' \
        """ + f"-H 'Authorization: token {token}'" + """ \
        -d '{"name":"dep2", "private":true}'
    """)
    print(dep2)

    dep_commits = client.succeed("""
    (
    git clone http://gitea:3000/test/dep.git
    cd dep
    touch file
    git add file
    git commit -m 'init'
    git push
    cd ..

    git clone http://gitea:3000/test/dep2.git
    cd dep2
    touch file
    git add file
    git commit -m 'init dep2'
    git push
    cd ..

    git clone http://gitea:3000/test/repo.git
    cd repo
    cat >flake.nix <<EOF
    {
      inputs.dep = {
        url = "git+http://gitea:3000/test/dep";
        flake = false;
      };
      # a different input name as opposed to repo name
      inputs.dep2input = {
        url = "git+http://gitea:3000/test/dep2";
        flake = false;
      };
      outputs = { ... }: {
      };
    }
    EOF
    ls -al
    cat flake.nix
    git add .
    nix flake lock -v --extra-experimental-features nix-command\ flakes
    git add .
    git commit -m 'init'
    git push
    cd ..

    cd dep
    echo v2 >file
    git add file
    git commit -m 'init'
    git push
    git log --format=oneline
    cd ..
    ) 1>&2
    (
    cd dep
    git log --format=%H
    )
    """).splitlines()

    assert len(dep_commits) == 2

    agent.succeed(f"echo {gitea_admin_password} | effect-update")

    repo_update_rev = client.succeed(f"""
      (
        set -x
        cd repo
        git fetch origin
        git checkout flake-update
        grep '{dep_commits[0]}' <flake.lock
        git log 1>&2
        git log | grep 'flake.lock: Update'
        # The commit message mentions the hostname
        git log | grep gitea
        # The commit hashes occur in the message
        # We only check for shortRev length, which is 7
        git log | grep '{dep_commits[0][:7]}'
        git log | grep '{dep_commits[1][:7]}'
      ) 1>&2
      (cd repo; git rev-parse HEAD)
    """).rstrip()

    with subtest("Idempotent and successful when up to date"):
      agent.succeed(f"echo {gitea_admin_password} | effect-update")
      client.succeed(f"""
        (
          set -x
          cd repo
          git pull
          [[ $(git rev-parse HEAD) == {repo_update_rev} ]]
        )
    """)

    # repoName: name of the repo checkout directory on `client`
    def updateRepo(repoName):
      return client.succeed(f"""
        (
          set -x
          cd {repoName}
          git log
          echo changed >>file
          git add file
          git commit -m 'file: change'
          git push
          git log
          cd ../repo
          git log
        ) 1>&2
        (cd {repoName}; git rev-parse HEAD)
      """).rstrip()

    with subtest("Works when pullRequest body is empty"):

      depRev = updateRepo("dep")
      agent.succeed(f"echo {gitea_admin_password} | effect-update-no-pr-body")
      # FIXME: actually enable pull request for this effect, using a different backend, and/or by implementing it for gitea (useless for now), and check that it is created
      client.succeed(f"""
        (
          set -x
          cd repo
          git pull
          git log
          grep {depRev} <flake.lock
        ) 1>&2
      """)

    with subtest("Can select specific input to update"):
      depRev = updateRepo("dep")
      dep2Rev = updateRepo("dep2")
      agent.succeed(f"echo {gitea_admin_password} | effect-update-dep2input")
      client.succeed(f"""
        (
          set -x
          cd repo
          git pull
          git log
          git log | grep "Update dep2input with custom message"
          ! grep {depRev} <flake.lock
          grep {dep2Rev} <flake.lock
        ) 1>&2
      """)
  '';
}
