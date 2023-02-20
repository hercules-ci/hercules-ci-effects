"""
Environment:
  - files: JSON value of type `Array<string | {path: string, label: string}>`;
    files to use for release
  - check_only: if present, do not perform release, only check that files
    exist and create $out file
  - if check_only is not present:
    - owner, repo, releaseTag: information about repository
"""

from dataclasses import dataclass
import json
from os import getcwd, environ, execlp, rename, symlink
from os.path import exists, isdir, isfile
import subprocess
from typing import Dict, List, Literal, Tuple


@dataclass
class File:
    label: str
    path: str


@dataclass
class Archive:
    label: str
    paths: List[str]
    archiver: Literal["zip"]


def parse_spec(spec) -> File | Archive:
    e = Exception(
        "Every SPEC must be a {label: string, path: string} "
        "or a {label: string, paths: [string], archiver: 'zip'}, "
        f"instead we got: {spec}"
    )
    if type(spec) is not dict:
        raise e
    if "label" not in spec or type(spec["label"]) is not str:
        raise e
    # spec is a file
    if "path" in spec and type(spec["path"]) is str:
        return File(spec["label"], spec["path"])
    # spec is an archive
    if "paths" in spec and \
            type(spec["paths"]) is list and \
            all(type(e) is str for e in spec["paths"]) and \
            spec.get("archiver") in ["zip"]:
        return Archive(spec["label"], spec["paths"], spec["archiver"])
    raise e


specs = [parse_spec(spec) for spec in json.loads(environ["files"])]
specs_by_label: Dict[str, Tuple[int, File | Archive]] = {}

for i, spec in enumerate(specs):
    if type(spec) is File:
        print(
            f"Checking that path {spec.path} "
            f"with label `{spec.label}` exists: \t", end="")
        try:
            if not isfile(spec.path):
                print("not a file")
                exit(1)
        except Exception as e:
            print("cannot access")
            raise e
        print("OK")
    elif type(spec) is Archive:
        print(f"Checking that every path from {spec.label} exists:")
        if len(spec.paths) == 0:
            raise Exception(f"`[{i}].paths` is an empty list")
        for path in spec.paths:
            print(f"  {path}: \t", end="")
            try:
                if not exists(path):
                    print("cannot access")
                    exit(1)
            except Exception as e:
                print("cannot access")
                raise e
            print("OK")

    if spec.label in specs_by_label:
        prev_i, prev_spec = specs_by_label[spec.label]
        print(
            f"Duplicate labels: spec #{prev_i} `{prev_spec}` "
            f"and spec #{i} `{spec}`"
        )
        exit(1)
    specs_by_label[spec.label] = (i, spec)

if "check_only" in environ:
    print("check_only is present, creating $out")
    open(environ["out"], "w")
else:
    for spec in specs:
        if type(spec) is File:
            symlink(spec.path, spec.label)
        elif type(spec) is Archive:
            if spec.archiver == "zip":
                pwd = getcwd()
                for path in spec.paths:
                    if isdir(path):
                        subprocess.run(
                            ["zip", "-r", f"{pwd}/archive.zip", "."],
                            cwd=path,
                            check=True
                        )
                    else:
                        subprocess.run(
                            ["zip", "-r", f"{pwd}/archive.zip", path],
                            check=True
                        )
                rename("archive.zip", spec.label)
    execlp(
        "gh",
        "gh", "release", "create",
        "--repo", f"{environ['owner']}/{environ['repo']}",
        environ["releaseTag"],
        *(spec.label for spec in specs)
    )
