{
  description = "Auto-generated dev shells for all packages in nixpkgs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    inherit (nixpkgs.lib.attrsets) genAttrs mapAttrsRecursiveCond;
    inherit (builtins) mapAttrs;

    supportedSystems = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];

    # Generates
    # {
    #   aarch64-linux = <pkgs for aarch64-linux>;
    #   x86_64-linux = <pkgs for x86_64-linux>;
    #   ...
    # }
    pkgsEachSystem = genAttrs supportedSystems (system: import nixpkgs {inherit system;});

    # Given a devShellFunc (pkgs: pkg: <devShell>),
    # generates devShells for all derivations in nixpkgs
    # {
    #   aarch64-linux = {
    #     foo = "<devShell for foo>";
    #     bar = "<devShell for bar>";
    #     ...
    #   };
    #   x86_64-linux = ...
    # };
    mkDevShells = mkDevShellFunc:
      genAttrs supportedSystems (
        system: let
          pkgs = pkgsEachSystem."${system}";
        in
          mapAttrsRecursiveCond
          # Derivations are also attributeSets,
          # but they have an attribute "type" = "derivation";
          ({type ? "unknown", ...}: type != "derivation")
          (
            _: pkg:
              mkDevShellFunc pkgs pkg
          )
          pkgs
      );

    stdenvOverrides = {
      default = pkgs: {};
      clang = pkgs: {stdenv = pkgs.clangStdenv;};
      gcc = pkgs: {stdenv = pkgs.gccStdenv;};
    };

    mkCDevShell = {
      pkgs,
      pkg,
      mkShellOverride ? {},
      extraPackages ? [],
      shellHookPre ? "",
    }:
      pkgs.mkShell.override mkShellOverride {
        packages = [pkgs.bear pkgs.clang-tools pkgs.ccls pkgs.zsh] ++ extraPackages;
        inputsFrom = [pkg];

        hardeningDisable = ["fortify"];

        shellHook =
          shellHookPre
          + ''
            exec zsh
          '';
      };

    mkMesonDevShell = {
      pkgs,
      pkg,
      mkShellOverride ? {},
      extraPackages ? [],
      shellHookPre ? "",
    }:
      mkCDevShell {
        inherit pkgs pkg mkShellOverride extraPackages;
        shellHookPre =
          shellHookPre
          + ''
            ln -s ./build/compile_commands.json
            meson setup build
            ninja -C build
          '';
      };
  in {
    cdevShells =
      mapAttrs (
        _: stdenvOverride:
          mkDevShells (pkgs: pkg:
            mkCDevShell {
              inherit pkgs pkg;
              mkShellOverride = stdenvOverride pkgs;
            })
      )
      stdenvOverrides;

    mesonDevShells =
      mapAttrs (
        _: stdenvOverride:
          mkDevShells (pkgs: pkg:
            mkMesonDevShell {
              inherit pkgs pkg;
              mkShellOverride = stdenvOverride pkgs;
            })
      )
      stdenvOverrides;
  };
}
