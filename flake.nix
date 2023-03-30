{
  description = "Applying Open Policy Agent policies to Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    nuenv.url = "github:DeterminateSystems/nuenv";
  };

  outputs = { self, nixpkgs, nuenv }:
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
            nuenv.overlays.nuenv
            self.overlays.opaWasm
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
        default = pkgs.mkOpaWasm {
          name = "example-policy";
          src = ./.;
          policy = ./verify.rego;
          entrypoint = "verify/allow";
        };

        opa-eval = pkgs.rustPlatform.buildRustPackage {
          name = "opa-eval";
          src = ./rust-opa-wasm;
          cargoLock.lockFile = ./rust-opa-wasm/Cargo.lock;
          buildFeatures = [ "cli" ];
          doCheck = false;
        };

        evaluate = pkgs.nuenv.mkScript {
          name = "evaluate";
          script = ''
            # An OPA evaluator
            def main [
              --entrypoint: string, # The output entrypoint
            ] {
              # TODO: make this multiple lines without losing output
              ${self.packages.${system}.opa-eval}/bin/opa-eval --module ${self.packages.${system}.default}/lib/policy.wasm --entrypoint $entrypoint
            }
          '';
        };
      });

      lib = {
        mkOpaWasm =
          pkgs:
          { name, src, policy, entrypoint }:
          pkgs.nuenv.mkDerivation {
            inherit entrypoint name policy src;
            packages = with pkgs; [ gnutar gzip open-policy-agent ];
            build = builtins.readFile ./opa-wasm.nu;
          };
      };

      overlays = rec {
        default = opaWasm;

        opaWasm = final: prev: {
          mkOpaWasm = self.lib.mkOpaWasm prev;
        };
      };
    };
}
