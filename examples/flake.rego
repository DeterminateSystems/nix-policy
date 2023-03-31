package flake

import input as flake_lock

# METADATA
# title: flake-utils considered harmful
# description: Flakes can't use flake-utils as an input
# custom:
#   severity: FATAL
deny[format(rego.metadata.rule())] {
    has_key(flake_lock.nodes, "flake-utils")
}

has_key(obj, k) { _ = obj[k] }

format(meta) := {"problem": meta.description, "severity": meta.custom.severity}
