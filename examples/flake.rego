package flake

import input as flake_lock

# METADATA
# title: Unstable version of Nixpkgs used
# description: You can't use nixpkgs-unstable or nixos-unstable
# custom:
#   severity: FATAL
deny[format(rego.metadata.rule())] {
    has_key(flake_lock.nodes, "nixpkgs")
    has_key(flake_lock.nodes.nixpkgs.original, "ref")
    ref := flake_lock.nodes.nixpkgs.original.ref
    prohibited_refs := ["nixpkgs-unstable", "nixos-unstable"]
    ref == prohibited_refs[_]
}

has_key(obj, k) { _ = obj[k] }

format(meta) := {
    "problem": meta.description,
    "severity": meta.custom.severity
}
