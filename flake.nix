{
  description = "Applying Open Policy Agent policies to Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    nuenv = {
      url = "github:DeterminateSystems/nuenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nuenv, rust-overlay }:
    let
      systems = [
        "aarch64-linux"
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f {
        inherit system;
        pkgs = import nixpkgs {
          overlays = [
            rust-overlay.overlays.rust-overlay
            self.overlays.provide-rust
            nuenv.overlays.nuenv
            self.overlays.opa-wasm
          ];
          inherit system;
        };
      });
    in
    {
      devShells = forAllSystems ({ pkgs, system }: {
        default = pkgs.mkShell {
          name = "nix-policy";
          packages = with pkgs; [
            open-policy-agent
            wasmtime
          ];
        };
      });

      packages = forAllSystems ({ pkgs, system }: {
        default = pkgs.mkPolicyEvaluator {
          name = "opa-verify";
          src = ./.;
          policy = ./verify.rego;
          entrypoint = "verify/allow";
        };
      });

      lib = {
        mkPolicyEvaluator =
          pkgs:

          { name, src, policy, entrypoint }:

          let
            policyName = builtins.baseNameOf policy;

            policyDrv = pkgs.nuenv.mkDerivation {
              name = "${name}-policy";
              inherit entrypoint policy src;
              packages = with pkgs; [ gnutar gzip open-policy-agent ];
              build = builtins.readFile ./opa-wasm.nu;
            };

            rustPlatform = pkgs.makeRustPlatform {
              rustc = pkgs.rustToolchain;
              cargo = pkgs.rustToolchain;
            };
          in
          rustPlatform.buildRustPackage {
            inherit name;
            src = ./eval;
            cargoLock = {
              lockFile = ./eval/Cargo.lock;
              outputHashes = {
                "opa-wasm-0.1.0" = "sha256-ZasUQHHBLnGtGB+pkN/jjgXL0iVeCPA/q1Dxl5QAhQ0=";
              };
            };
            prePatch = ''
              substituteInPlace src/main.rs \
                --replace %policy% ${policyDrv}/lib/policy.wasm \
                --replace %rego% ${policyName} \
                --replace %entrypoint% ${entrypoint}
            '';
            postInstall = ''
              mv $out/bin/eval $out/bin/${name}
            '';
          };
      };

      overlays = {
        provide-rust = final: prev: {
          rustToolchain = prev.rust-bin.fromRustupToolchainFile ./eval/rust-toolchain.toml;
        };

        opa-wasm = final: prev: {
          mkPolicyEvaluator = self.lib.mkPolicyEvaluator prev;
        };
      };
    };
}
