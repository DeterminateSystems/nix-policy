def bl [msg: string] { $"(ansi blue)($msg)(ansi reset)" }
def gr [msg: string] { $"(ansi light_green)($msg)(ansi reset)" }

let out = $env.out
let outLib = $"($out)/lib"

let tarball = "bundle.tar.gz"
let wasmOutput = "policy.wasm"
let policy = $env.policy
let relativePolicyPath = ($policy | parse $"($env.NIX_STORE)/{__hash}-{policy}" | get policy.0)
let policyName = ($relativePolicyPath | parse "{policy}.rego" | get policy.0)
let entrypoint = $env.entrypoint

log $"Building Wasm policy (bl $relativePolicyPath) with entrypoint (gr $entrypoint)"

let opaCmd = $"opa build --target wasm --entrypoint ($entrypoint) ($policy)"

log $"Running (gr $opaCmd)"

nu --commands $opaCmd

log $"Untarring ($tarball)"

log "Tar output:"
tar xvzf $tarball

log $"Making output directory (bl $out)"

mkdir $outLib

log $"Copying (bl $wasmOutput) to (gr $outLib)"

mv $wasmOutput $outLib
