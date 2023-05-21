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
    { self, ... }@inputs:

    let
      systems = [
        "aarch64-linux"
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      overlays = [
        inputs.rust-overlay.overlays.rust-overlay # Provide rust-bin attribute
        self.overlays.default # Provide rustToolchain and mkPolicyEvaluator attributes
        inputs.nuenv.overlays.nuenv # Provide the nuenv attribute (for nuenv.mkDerivation)
      ];

      forAllSystems = f: inputs.nixpkgs.lib.genAttrs systems (system: f {
        inherit system;
        pkgs = import inputs.nixpkgs {
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
        default = rbac-eval;

        rbac-eval = pkgs.mkPolicyEvaluator {
          name = "rbac-eval";
          src = ./.;
          policy = ./examples/rbac.rego;
          entrypoint = "rbac";
        };

        tfstate-eval = pkgs.mkPolicyEvaluator {
          name = "tfstate-eval";
          src = ./.;
          policy = ./examples/tfstate.rego;
          entrypoint = "tfstate";
        };

        check-flake = pkgs.mkPolicyEvaluator {
          name = "check-flake";
          src = ./.;
          policy = ./examples/flake.rego;
          entrypoint = "flake/deny";
        };

        # A Nushell script wrapping the check-flake package
        flake-checker = pkgs.nuenv.mkScript {
          name = "flake-checker";
          script = ''
            # Checks that a flake.lock file conforms to Determinate Systems' strict policies
            def main [
              path: path = "./flake.lock", # The flake.lock file to check (default: "./flake.lock")
            ] {
              let res = (
                ${self.packages.${system}.check-flake}/bin/check-flake
                  --input-path $path
                  --data-path ${./examples/flake.json}
              )
              let result = ($res | from json | get 0.result)

              let numProblems = ($result | length)
              if $numProblems == 0 {
                print $"(ansi green)SUCCESS(ansi reset)"
              } else {
                let problem = $"problem(if $numProblems > 1 { "s" })"
                let was = (if $numProblems > 1 { "were" } else { "was" })
                print $"(ansi red)ERROR(ansi reset): (ansi blue)($numProblems)(ansi reset) ($problem) ($was) encountered"

                for problem in $result {
                  if $problem.issue == "disallowed-nixpkgs-ref" {
                    print $"> Disallowed Git ref for Nixpkgs: (ansi red)($problem.detail.disallowed_ref)(ansi reset)"
                  }

                  if $problem.issue == "outdated-nixpkgs-ref" {
                    print $"> Outdated Nixpkgs dependency is (ansi red)($problem.detail.age_in_days)(ansi reset) days old while the limit is (ansi blue)($problem.detail.max_days)(ansi reset)"
                  }
                }
              }
            }
          '';
        };
      });

      lib = {
        # The OPA Wasm -> Rust CLI tool builder
        mkPolicyEvaluator = pkgs: import ./nix/evaluator.nix { inherit pkgs; };
      };

      overlays = {
        default = final: prev: rec {
          rustToolchain = prev.rust-bin.fromRustupToolchainFile ./eval/rust-toolchain.toml;
          mkPolicyEvaluator = self.lib.mkPolicyEvaluator final;
        };
      };
    };
}
