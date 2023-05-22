package flake

import data.allowed_refs as allowed_refs
import data.max_days as max_days
import future.keywords.in
import input as flake_lock

# Constants and helper functions
has_key(obj, k) {
    _ = obj[k]
}

# Deny flake.lock files with a Git ref that's not included in the provided data.json
deny[{
	"issue": "disallowed-nixpkgs-ref",
	"detail": {
		"disallowed_ref": ref,
	},
}] {
    has_key(flake_lock.nodes.root.inputs, "nixpkgs")
    nixpkgs_root := flake_lock.nodes.root.inputs.nixpkgs
    nixpkgs := flake_lock.nodes[nixpkgs_root]
    has_key(nixpkgs.original, "ref")
    ref := nixpkgs.original.ref
    not ref in allowed_refs
}

# Deny flake.lock files where any Nixpkgs was last updated more than 30 days ago
deny[{
    "issue": "outdated-nixpkgs-ref",
    "detail": {
        "age_in_days": floor(age / ((24 * 60) * 60)),
        "max_days": data.max_days,
    },
}] {
    has_key(flake_lock.nodes.root.inputs, "nixpkgs")
    nixpkgs_root := flake_lock.nodes.root.inputs.nixpkgs
    nixpkgs := flake_lock.nodes[nixpkgs_root]
    last_mod := nixpkgs.locked.lastModified
    age := (time.now_ns() / 1000000000) - last_mod
    secs_per_max_period := max_days * ((24 * 60) * 60)
    age > secs_per_max_period
}
