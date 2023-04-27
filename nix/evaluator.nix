{ pkgs # Pinned Nixpkgs (from overlay)
}:

{ name # The name of the final executable
, src # The relative source root
, policy # The Rego policy file
, entrypoint # The OPA entrypoint
}:

let
  # Convert /nix/store/...-policy.rego into policy.rego
  policyName = builtins.baseNameOf policy;

  # Rust toolchain (from overlay)
  rust = pkgs.rustToolchain;

  # Rust platform derived from Rust toolchain
  rustPlatform = pkgs.makeRustPlatform {
    rustc = rust;
    cargo = rust;
  };

  # Build a Wasm binary for the specified policy and entrypoint
  policyDrv = pkgs.nuenv.mkDerivation {
    name = "${name}-policy";
    inherit entrypoint policy src;
    packages = with pkgs; [ binaryen gnutar gzip open-policy-agent ];
    build = builtins.readFile ./nu/opa-wasm.nu;
  };
in
rustPlatform.buildRustPackage {
  inherit name;
  src = ../eval;
  cargoLock = {
    lockFile = ../eval/Cargo.lock;
    outputHashes = {
      # Required because this is a git dependency, not crates.io
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
  doCheck = false; # No tests yet
}
