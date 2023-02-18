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
from os import environ, execlp, symlink
from os.path import isfile
from typing import Dict, Tuple


def parse_file(file):
    if type(file) is dict and \
            "path" in file and \
            type(file["path"]) is str and \
            "label" in file and \
            type(file["label"]) is str:
        return file
    raise Exception(
        "Every FILE must be a {path: string, label: string}"
        f", instead we got: {file}"
    )


def file_to_gh_repr(file):
    path = file["path"]
    label = file["label"]
    return path + (label and f"#{label}" or "")


files = [parse_file(file) for file in json.loads(environ["files"])]
files_by_label: Dict[str, Tuple[int, Dict[str, str]]] = {}

for i, file in enumerate(files):
    path = file["path"]
    label = file["label"]
    labelMessage = label and f"with label `{label}` " or ""
    print(f"Checking that path {path} {labelMessage}exists: ", end="")
    try:
        if not isfile(path):
            print("Not a file")
            exit(1)
    except Exception as e:
        print(f"Cannot access {path}")
        raise e
    print("OK")
    if label in files_by_label:
        prev_i, prev_file = files_by_label[label]
        print(
            "Duplicate labels: "
            f"file #{prev_i} {file_to_gh_repr(prev_file)} "
            f"and file #{i} {file_to_gh_repr(file)}"
        )
        exit(1)
    files_by_label[label] = (i, file)

if "check_only" in environ:
    print("check_only is present, creating $out")
    open(environ["out"], "w")
else:
    for file in files:
        path = file["path"]
        label = file["label"]
        symlink(path, label)
    execlp(
        "gh",
        "gh", "release", "create",
        "--repo", f"{environ['owner']}/{environ['repo']}",
        "--verify-tag", environ["releaseTag"],
        *(file["label"] for file in files)
    )
