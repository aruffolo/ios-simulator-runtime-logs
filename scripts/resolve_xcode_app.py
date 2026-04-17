#!/usr/bin/env python3

import argparse
import json
import subprocess
from pathlib import Path


IGNORED_PARTS = {
    ".git",
    ".build",
    "DerivedData",
    "Pods",
    "Carthage",
    "node_modules",
    ".swiftpm",
    ".xcframework-build",
    "build-artifacts",
    "SourcePackages",
}


def parse_args():
    parser = argparse.ArgumentParser(description="Resolve Xcode workspace/project, scheme, and app target.")
    parser.add_argument("--workspace")
    parser.add_argument("--project")
    parser.add_argument("--scheme")
    parser.add_argument("--configuration")
    parser.add_argument("--destination")
    parser.add_argument("--derived-data-path")
    parser.add_argument("--cwd", default=".")
    return parser.parse_args()


def fail(message, details=None, code=1):
    payload = {"error": message}
    if details is not None:
        payload["details"] = details
    print(json.dumps(payload, indent=2))
    raise SystemExit(code)


def visible_paths(root: Path, suffix: str):
    paths = []
    for path in root.rglob(f"*{suffix}"):
        if should_ignore(path):
            continue
        paths.append(path)
    return sorted(paths)


def should_ignore(path: Path):
    if path.name == "project.xcworkspace" and path.parent.suffix == ".xcodeproj":
        return True
    for part in path.parts:
        if part in IGNORED_PARTS:
            return True
        if part.startswith(".derivedData"):
            return True
    return False


def run_json(command):
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        fail("Command failed.", {"command": command, "stderr": result.stderr.strip(), "stdout": result.stdout.strip()})
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        fail("Command did not return JSON.", {"command": command, "error": str(exc), "stdout": result.stdout[:2000]})


def choose_entry(root: Path, workspace_arg: str | None, project_arg: str | None):
    if workspace_arg and project_arg:
        fail("Pass only one of --workspace or --project.")
    if workspace_arg:
        return ("workspace", str((root / workspace_arg).resolve()))
    if project_arg:
        return ("project", str((root / project_arg).resolve()))

    workspaces = visible_paths(root, ".xcworkspace")
    projects = visible_paths(root, ".xcodeproj")
    if len(workspaces) == 1:
        return ("workspace", str(workspaces[0]))
    if len(workspaces) > 1:
        fail("Multiple workspaces found; specify --workspace.", [str(path) for path in workspaces])
    if len(projects) == 1:
        return ("project", str(projects[0]))
    if len(projects) > 1:
        fail("Multiple projects found; specify --project.", [str(path) for path in projects])
    fail("No Xcode workspace or project found.")


def list_schemes(entry_kind: str, entry_path: str):
    payload = run_json(["xcodebuild", "-list", "-json", f"-{entry_kind}", entry_path])
    container = payload.get("workspace") or payload.get("project") or {}
    return container.get("schemes") or []


def choose_scheme(entry_kind: str, entry_path: str, explicit_scheme: str | None):
    schemes = list_schemes(entry_kind, entry_path)
    if explicit_scheme:
        if explicit_scheme in schemes:
            return explicit_scheme
        fail("Requested scheme not found.", {"requested": explicit_scheme, "schemes": schemes})
    if len(schemes) == 1:
        return schemes[0]
    stem = Path(entry_path).stem
    exact = [scheme for scheme in schemes if scheme == stem]
    if len(exact) == 1:
        return exact[0]
    app_like = rank_app_like_schemes(schemes, stem)
    if len(app_like) == 1:
        return app_like[0]
    details = {"all_schemes": schemes}
    if app_like:
        details["likely_app_schemes"] = app_like
        fail("Multiple app-like schemes found; specify --scheme.", details)
    fail("Multiple schemes found; specify --scheme.", details)


def rank_app_like_schemes(schemes, stem: str):
    blocked_tokens = {
        "tests",
        "uitests",
        "pods",
        "extension",
        "service",
        "notification",
        "generated",
        "framework",
        "sdk",
        "core",
        "swiftlint",
        "swiftformat",
    }
    ranked = []
    for scheme in schemes:
        lower = scheme.lower()
        if any(token in lower for token in blocked_tokens):
            continue
        score = 0
        if lower.startswith(stem.lower()):
            score += 3
        if "prod" in lower:
            score += 2
        if "dev" in lower or "debug" in lower:
            score += 1
        if "mock" in lower:
            score -= 1
        ranked.append((score, scheme))
    ranked.sort(key=lambda item: (-item[0], item[1]))
    ordered = [scheme for _, scheme in ranked]
    family = [scheme for scheme in ordered if scheme.lower().startswith(stem.lower())]
    if family:
        return family
    return ordered


def show_build_settings(entry_kind: str, entry_path: str, scheme: str, configuration: str, destination: str | None, derived_data_path: str | None):
    command = [
        "xcodebuild",
        f"-{entry_kind}", entry_path,
        "-scheme", scheme,
        "-showBuildSettings",
        "-json",
    ]
    if configuration:
        command.extend(["-configuration", configuration])
    if destination:
        command.extend(["-destination", destination])
    if derived_data_path:
        command.extend(["-derivedDataPath", derived_data_path])
    return run_json(command)


def pick_app_target(payload, scheme: str):
    app_targets = []
    for item in payload:
        settings = item.get("buildSettings", {})
        if settings.get("WRAPPER_EXTENSION") != "app":
            continue
        app_targets.append({"target": item.get("target"), "settings": settings})
    if not app_targets:
        fail("No app target found in build settings.")
    exact = [item for item in app_targets if item["target"] == scheme]
    if len(exact) == 1:
        return exact[0]
    by_product = [item for item in app_targets if item["settings"].get("PRODUCT_NAME") == scheme]
    if len(by_product) == 1:
        return by_product[0]
    if len(app_targets) == 1:
        return app_targets[0]
    fail("Multiple app targets found; specify a more precise scheme.", [item["target"] for item in app_targets])


def main():
    args = parse_args()
    root = Path(args.cwd).resolve()
    entry_kind, entry_path = choose_entry(root, args.workspace, args.project)
    scheme = choose_scheme(entry_kind, entry_path, args.scheme)
    payload = show_build_settings(
        entry_kind,
        entry_path,
        scheme,
        args.configuration,
        args.destination,
        args.derived_data_path,
    )
    app_target = pick_app_target(payload, scheme)
    settings = app_target["settings"]
    result = {
        "entry_kind": entry_kind,
        "entry_path": entry_path,
        "scheme": scheme,
        "configuration": settings.get("CONFIGURATION", args.configuration or ""),
        "app_target": app_target["target"],
        "bundle_id": settings.get("PRODUCT_BUNDLE_IDENTIFIER", ""),
        "app_path": str(Path(settings["TARGET_BUILD_DIR"]) / settings["WRAPPER_NAME"]),
        "target_build_dir": settings["TARGET_BUILD_DIR"],
        "wrapper_name": settings["WRAPPER_NAME"],
    }
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
