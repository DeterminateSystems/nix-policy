# Policy-driven Nix

An experiment using [Nix] with [Open Policy Agent][opa] (OPA).

```shell
# Generate a Wasm binary from an OPA policy
nix build --print-build-logs

ls result/bin
# policy.wasm
```

## Create your own evaluator

This bit of Nix enables you to generate your own evaluator CLI tool from `rbac.rego` and with the entrypoint `rbac/allow`.

```nix
{
  inputs = {
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
        policy = ./rbac.rego;
        entrypoint = "rbac/allow";
      };
    });
  };
}
```

[nix]: https://zero-to-nix.com
[opa]: https://open-policy-agent.org
