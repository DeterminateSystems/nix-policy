# Policy-driven Nix

An experiment using [Nix] with [Open Policy Agent][opa] (OPA).

## How it works

This project uses [Nix] to create CLI tools that wrap [Rego] policies for [Open Policy Agent][opa]:

- The OPA CLI tool generates a [WebAssembly] (Wasm) binary for the specified Rego policy file and [entrypoint][bundle]
- A [Rust CLI](./eval) wraps the generated Wasm and provides the final user interface.
  That CLI is itself a thin wrapper around the [`rust-opa-wasm`][lib] library from the good folks at [Matrix].

You can run the default example for the [`rbac.rego`](./examples/rbac.rego):

```shell
# Generate a Wasm binary from an OPA policy
nix build --print-build-logs

./result/bin/rbac-verify \
  --input '{"password":"opensesame"}' \
  --data '{"expected":"opensesame"}'
# [{"result":true}]

./result/bin/rbac-verify \
  --input '{"password":"somethingelse"}' \
  --data '{"expected":"opensesame"}'
# [{"result":false}]
```

## Create your own evaluator

This bit of Nix would enable you to generate your own evaluator CLI tool from `terraform.rego` and with the entrypoint `terraform/allow`.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    nix-policy.url = "github:DeterminateSystems/nix-policy";
  };

  outputs = { self, nix-policy }:
    let
      systems = [
        "aarch64-linux"
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f {
        pkgs = import nixpkgs { inherit system; overlays = [ nix-policy-overlays.opa-wasm ]; };
      });
    in
    {
      packages = forAllSystems ({ pkgs }: {
        default = pkgs.mkPolicyEvaluator {
          name = "evaluate-tf-state";
          src = ./.;
          policy = ./policies/terraform.rego;
          entrypoint = "terraform/allow";
        };
      });
    };
}
```

Then you can build and run:

```shell
nix build

./result/bin/evaluate-tf-state \
  --input $(cat ./terraform.tfstate) \
  --data $(cat ./policy-data.json)
```

[bundle]: https://www.openpolicyagent.org/docs/latest/management-bundles/#bundle-file-format
[lib]: https://github.com/matrix-org/rust-opa-wasm
[matrix]: https://github.com/matrix-org
[nix]: https://zero-to-nix.com
[opa]: https://open-policy-agent.org
[rego]: https://www.openpolicyagent.org/docs/latest/policy-language
[webassembly]: https://webassembly.org
