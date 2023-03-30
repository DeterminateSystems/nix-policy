def h [msg: string] { $"(ansi blue)($msg)(ansi reset)" }

let outBin = $"($env.out)/bin"

let policy = $env.policy
let relativePolicyPath = ($policy | parse $"($env.NIX_STORE)/{__hash}-{policy}" | get policy.0)
let policyName = ($relativePolicyPath | parse "{policy}.rego" | get policy.0)
let entrypoint = $env.entrypoint

log $"Building Wasm policy (h $relativePolicyPath) with entrypoint (h $entrypoint)"

(
  opa build
    --target wasm
    --entrypoint $entrypoint
    $policy
)

tar -xzf bundle.tar.gz

mkdir $outBin

mv policy.wasm $outBin
