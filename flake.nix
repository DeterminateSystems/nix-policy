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

  outputs =
    { self
    , nixpkgs
    , nuenv
    , rust-overlay
    }:

    let
      systems = [
        "aarch64-linux"
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      overlays = [
        rust-overlay.overlays.rust-overlay # Provide rust-bin attribute
        self.overlays.rust-toolchain # Provide a rustToolchain attribute
        nuenv.overlays.nuenv # Provide the nuenv attribute (for nuenv.mkDerivation)
        self.overlays.opa-eval # Provide the mkPolicyEvaluator attribute
      ];

      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f {
        inherit system;
        pkgs = import nixpkgs {
          inherit overlays system;
        };
      });
    in
    {
      devShells = forAllSystems ({ pkgs, system }: {
        default = pkgs.mkShell {
          name = "nix-policy";
          packages = with pkgs; [
            open-policy-agent
            rustToolchain
            cargo-edit
            cargo-watch
          ];
        };

        ci = pkgs.mkShell {
          name = "nix-policy-ci";
          packages = with pkgs; [
            cachix
            direnv
          ];
        };
      });

      packages = forAllSystems ({ pkgs, system }: rec {
        default = rbac;

        rbac = pkgs.mkPolicyEvaluator {
          name = "rbac-verify";
          src = ./.;
          policy = ./examples/rbac.rego;
          entrypoint = "rbac";
        };

        tfstate = pkgs.mkPolicyEvaluator {
          name = "tfstate-verify";
          src = ./.;
          policy = ./examples/tfstate.rego;
          entrypoint = "tfstate";
        };

        check-flake = pkgs.mkPolicyEvaluator {
          name = "flake-checker";
          src = ./.;
          policy = ./examples/flake.rego;
          entrypoint = "flake";
        };

        flake-checker = pkgs.nuenv.mkScript {
          name = "flake-checker";
          script = ''
            # Checks that a flake.lock file conforms to Determinate Systems' strict policies
            def main [
              path: path = "./flake.lock", # The flake.lock file to check (default: "./flake.lock")
            ] {
              ${self.packages.${system}.check-flake}/bin/flake-checker --input (open $path)
            }
          '';
        };
      });

      lib = {
        mkPolicyEvaluator = pkgs: import ./nix/evaluator.nix { inherit pkgs; };
      };

      overlays = {
        rust-toolchain = final: prev: rec {
          rustToolchain = prev.rust-bin.fromRustupToolchainFile ./eval/rust-toolchain.toml;
        };

        opa-eval = final: prev: {
          mkPolicyEvaluator = self.lib.mkPolicyEvaluator prev;
        };
      };
    };
}
