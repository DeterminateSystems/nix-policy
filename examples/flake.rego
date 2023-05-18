package flake

import input as flake_lock

# METADATA
# title: Incorrect version of Nixpkgs used
# description: You must pin to Nixpkgs with Git ref nixos-22.11
# custom:
#   severity: FATAL
deny[format(rego.metadata.rule())] {
    has_key(flake_lock.nodes, "nixpkgs")
    has_key(flake_lock.nodes.nixpkgs.original, "ref")
    ref := flake_lock.nodes.nixpkgs.original.ref
    ref != "nixos-22.11"
}

has_key(obj, k) { _ = obj[k] }

format(meta) := {
    "problem": meta.description,
    "severity": meta.custom.severity
}
