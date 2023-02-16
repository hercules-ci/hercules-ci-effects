"""
Environment:
  - files: JSON value of type `Array<string | {path: string, label: string}>`;
    files to use for release
  - check_only: if present, do not perform release, only check that files
    exist and create $out file
  - if check_only is not present:
    - owner, repo, releaseTag: information about repository
"""

import json
from os import environ, execlp
from os.path import isfile, realpath


def parse_file(file):
    if type(file) is str:
        return {'path': file, 'label': None}
    if type(file) is dict and \
            "path" in file and \
            type(file["path"]) is str and \
            "label" in file and \
            type(file["label"]) is str:
        return file
    raise Exception(
        "Every FILE must be either a string or a {{path: string, label: string}}, "
        f"instead we got: {file}")


def file_to_gh_repr(file):
    return file["path"] + (file["label"] and f"#{file['label']}" or "")


files = [parse_file(file) for file in json.loads(environ["files"])]

for file in files:
    path = file["path"]
    labelMessage = file["label"] and f"with label `{file['label']}` " or ""
    print(f"Checking that path {path} {labelMessage}exists: ", end="")
    try:
        rpath = realpath(path, strict=True)
        if not isfile(rpath):
            print("Not a file")
            exit(1)
    except Exception as e:
        print(f"Cannot access {path}")
        raise e
    print("OK")

if "check_only" in environ:
    print("check_only is present, creating $out")
    open(environ["out"], "w")
else:
    execlp(
        "gh",
        "gh", "release", "create",
        "--repo", f"{environ['owner']}/{environ['repo']}",
        "--verify-tag", environ["releaseTag"],
        *(file_to_gh_repr(file) for file in files)
    )
