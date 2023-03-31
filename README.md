# Policy-driven Nix

An experiment using [Nix] with [Open Policy Agent][opa] (OPA).

```shell
# Generate a Wasm binary from an OPA policy
nix build --print-build-logs

ls result/bin
# policy.wasm
```

```nix
{
  inputs = {
    nix-policy.url = "github:DeterminateSystems/nix-policy";
  };

  outputs = { self, nix-policy }: {};
}
```

[nix]: https://zero-to-nix.com
[opa]: https://open-policy-agent.org
