#!/usr/bin/env python3
# Copyright (c) Meta Platforms, Inc. and affiliates.
# All rights reserved.
#
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree.

"""
Generates info.json manifest files for Swift Package Manager artifact bundles.
Supports static library artifact bundles with platform-specific variants.
"""

import argparse
import json
import os
from typing import Dict, List


# Platform triple mappings
PLATFORM_TRIPLES = {
    "linux-x86_64": "x86_64-unknown-linux-gnu",
    "linux-aarch64": "aarch64-unknown-linux-gnu",
    "macos-arm64": "arm64-apple-macosx",
    "macos-x86_64": "x86_64-apple-macosx",
    "ios-arm64": "arm64-apple-ios",
    "ios-arm64-simulator": "arm64-apple-ios-simulator",
    "ios-x86_64-simulator": "x86_64-apple-ios-simulator",
}


def create_variant(
    platform: str,
    library_path: str,
    header_paths: List[str],
    modulemap_path: str,
) -> Dict:
    """Create a variant entry for the artifact bundle manifest."""
    if platform not in PLATFORM_TRIPLES:
        raise ValueError(f"Unknown platform: {platform}")

    variant = {
        "path": library_path,
        "supportedTriples": [PLATFORM_TRIPLES[platform]],
    }

    if header_paths or modulemap_path:
        metadata = {}
        if header_paths:
            metadata["headerPaths"] = header_paths
        if modulemap_path:
            metadata["moduleMapPath"] = modulemap_path
        variant["staticLibraryMetadata"] = metadata

    return variant


def create_manifest(
    artifact_name: str,
    version: str,
    variants: List[Dict],
) -> Dict:
    """Create the complete artifact bundle manifest."""
    return {
        "schemaVersion": "1.0",
        "artifacts": {
            artifact_name: {
                "type": "staticLibrary",
                "version": version,
                "variants": variants,
            }
        },
    }


def main():
    parser = argparse.ArgumentParser(
        description="Generate artifact bundle info.json manifest"
    )
    parser.add_argument(
        "--name",
        required=True,
        help="Artifact name (e.g., executorch)",
    )
    parser.add_argument(
        "--version",
        required=True,
        help="Artifact version (e.g., 1.2.0)",
    )
    parser.add_argument(
        "--platform",
        action="append",
        required=True,
        help="Platform identifier (e.g., linux-x86_64). Can be specified multiple times.",
    )
    parser.add_argument(
        "--library-path",
        action="append",
        required=True,
        help="Relative path to library for each platform (must match order of --platform)",
    )
    parser.add_argument(
        "--header-path",
        action="append",
        help="Relative path to headers directory for each platform (optional)",
    )
    parser.add_argument(
        "--modulemap-path",
        action="append",
        help="Relative path to module.modulemap for each platform (optional)",
    )
    parser.add_argument(
        "--output",
        required=True,
        help="Output path for info.json",
    )

    args = parser.parse_args()

    # Validate that we have the same number of platforms and library paths
    if len(args.platform) != len(args.library_path):
        raise ValueError("Number of --platform and --library-path arguments must match")

    # Create header paths list if provided, otherwise None for each platform
    header_paths_list = args.header_path if args.header_path else [None] * len(
        args.platform
    )
    if args.header_path and len(args.header_path) != len(args.platform):
        raise ValueError("If --header-path is provided, must match number of platforms")

    # Create modulemap paths list if provided, otherwise None for each platform
    modulemap_paths_list = args.modulemap_path if args.modulemap_path else [
        None
    ] * len(args.platform)
    if args.modulemap_path and len(args.modulemap_path) != len(args.platform):
        raise ValueError(
            "If --modulemap-path is provided, must match number of platforms"
        )

    # Create variants
    variants = []
    for i, platform in enumerate(args.platform):
        header_paths = (
            [header_paths_list[i]] if header_paths_list[i] is not None else []
        )
        modulemap_path = modulemap_paths_list[i]

        variant = create_variant(
            platform=platform,
            library_path=args.library_path[i],
            header_paths=header_paths,
            modulemap_path=modulemap_path,
        )
        variants.append(variant)

    # Create manifest
    manifest = create_manifest(
        artifact_name=args.name,
        version=args.version,
        variants=variants,
    )

    # Write to output file
    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
    with open(args.output, "w") as f:
        json.dump(manifest, f, indent=2)
        f.write("\n")  # Add trailing newline

    print(f"Generated manifest: {args.output}")


if __name__ == "__main__":
    main()
