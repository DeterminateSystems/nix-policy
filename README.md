# Policy-driven Nix

An experiment using [Nix] with [Open Policy Agent][opa] (OPA).

## How it works

This project uses [Nix] to create CLI tools that wrap [Rego] policies for [Open Policy Agent][opa]:

- The OPA CLI tool generates a [WebAssembly] (Wasm) binary for the specified Rego policy file and [entrypoint][bundle]
- A [Rust CLI](./eval) wraps the generated Wasm and provides the user interface

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

  outputs = { self, nix-policy }: let
    systems = [
      "aarch64-linux"
      "x86_64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
    ];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f {
      pkgs = import nixpkgs { inherit system; overlays = [ nix-policy-overlays.opa-wasm ]; }
    });
  in {
    packages = forAllSystems ({ pkgs }: {
      default = pkgs.mkPolicyEvaluator {
        name = "evaluate-rbac";
        src = ./.;
        policy = ./policies/terraform.rego;
        entrypoint = "terraform/allow";
      };
    });
  };
}
```

[bundle]: https://www.openpolicyagent.org/docs/latest/management-bundles/#bundle-file-format
[nix]: https://zero-to-nix.com
[opa]: https://open-policy-agent.org
[rego]: https://www.openpolicyagent.org/docs/latest/policy-language
[webassembly]: https://webassembly.org
