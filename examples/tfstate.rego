package tfstate

import input as tfstate

# METADATA
# title: Ensure minimum Terraform version
# description: Terraform version must be greater than the minimum specified in data.min_tf_version
# custom:
#   severity: FATAL
deny[format(rego.metadata.rule())] {
    tf_version := tfstate.version
    min_tf_version := data.min_tf_version
    semver.compare(tf_version, min_tf_version) == -1
}

# METADATA
# title: Ensure outputs
# description: Terraform state outputs must not be empty
# custom:
#   severity: HIGH
deny[format(rego.metadata.rule())] {
    count(tfstate.outputs) == 0
}

format(meta) := {"severity": meta.custom.severity, "reason": meta.description}
