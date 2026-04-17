#!/usr/bin/env python3

import json
import subprocess
import sys


def load_devices():
    output = subprocess.check_output(
        ["xcrun", "simctl", "list", "devices", "--json"],
        text=True,
    )
    payload = json.loads(output)
    devices = []
    for runtime_devices in payload.get("devices", {}).values():
        for device in runtime_devices:
            if not device.get("isAvailable", False):
                continue
            devices.append(
                {
                    "udid": device["udid"],
                    "name": device["name"],
                    "state": device["state"],
                }
            )
    return devices


def print_choice(device):
    print(f'{device["udid"]}\t{device["name"]}\t{device["state"]}')


def select_by_target(devices, target):
    target_lower = target.lower()
    exact_udid = [d for d in devices if d["udid"] == target]
    if exact_udid:
        return exact_udid
    exact_name = [d for d in devices if d["name"].lower() == target_lower]
    if exact_name:
        return exact_name
    partial_name = [d for d in devices if target_lower in d["name"].lower()]
    return partial_name


def main():
    devices = load_devices()
    booted = [d for d in devices if d["state"] == "Booted"]

    if len(sys.argv) > 1:
        matches = select_by_target(devices, sys.argv[1])
        if len(matches) == 1:
            print_choice(matches[0])
            return 0
        if not matches:
            print("No matching simulator found.", file=sys.stderr)
            return 1
        for device in matches:
            print_choice(device)
        return 2

    if len(booted) == 1:
        print_choice(booted[0])
        return 0
    if len(booted) > 1:
        for device in booted:
            print_choice(device)
        return 2

    for device in devices:
        print_choice(device)
    return 3


if __name__ == "__main__":
    raise SystemExit(main())
