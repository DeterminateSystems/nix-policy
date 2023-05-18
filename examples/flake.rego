package flake

import input as flake_lock
import future.keywords.in

# METADATA
# title: Incorrect version of Nixpkgs used
# description: You must pin to Nixpkgs with Git ref nixos-22.05 or nixos-22.11
# custom:
#   severity: FATAL
deny[format(rego.metadata.rule())] {
    has_key(flake_lock.nodes, "nixpkgs")
    has_key(flake_lock.nodes.nixpkgs.original, "ref")
    ref := flake_lock.nodes.nixpkgs.original.ref
    allowed := ["nixos-22.05", "nixos-22.11"]
    not ref in allowed
}

has_key(obj, k) { _ = obj[k] }

format(meta) := {
    "problem": meta.description,
    "severity": meta.custom.severity
}
