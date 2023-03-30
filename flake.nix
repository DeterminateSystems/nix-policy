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

        run =
          let
            runWasm = { name, binary, invoke }: pkgs.nuenv.mkScript {
              inherit name;
              script = ''
                (
                  ${pkgs.wasmtime}/bin/wasmtime ${binary}
                    --invoke ${invoke}
                )
              '';
            };
          in
          runWasm {
            name = "run";
            binary = "${self.packages.${system}.default}/bin/policy.wasm";
            invoke = "_start";
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
