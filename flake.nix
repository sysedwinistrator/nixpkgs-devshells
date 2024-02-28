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

    # Generate
    # {
    #   aarch64-linux = <pkgs for aarch64-linux>;
    #   x86_64-linux = <pkgs for x86_64-linux>;
    #   ...
    # }
    pkgsEachSystem = genAttrs supportedSystems (system: import nixpkgs {inherit system;});

    # Override stdenv in mkShell
    # Default is GCC on linux, clang on darwin
    stdenvOverrides = {
      default = pkgs: {};
      clang = pkgs: {stdenv = pkgs.clangStdenv;};
      gcc = pkgs: {stdenv = pkgs.gccStdenv;};
    };

    # Apply a devShellFunc (pkgs: pkg: <devShell>),
    # that generates a devShell for package pkg in package set pkgs,
    # to every package in pkgs.
    # In other words, convert set of packages to a set of devShells
    mkDevShellsForPkgs = {
      pkgs,
      devShellFunc,
    }:
      mapAttrsRecursiveCond
      # Derivations are also attributeSets,
      # but they have an attribute "type" = "derivation";
      ({type ? "unknown", ...}: type != "derivation")
      (
        _: pkg:
          devShellFunc pkgs pkg
      )
      pkgs;

    # Generate devShell set for each system
    # {
    #   aarch64-linux = {
    #     foo = "<devShell for foo>";
    #     bar = "<devShell for bar>";
    #     ...
    #   };
    #   x86_64-linux = ...
    # };
    mkDevShellsEachSystem = devShellFunc:
      genAttrs supportedSystems (
        system: let
          pkgs = pkgsEachSystem."${system}";
        in
          mkDevShellsForPkgs {inherit pkgs devShellFunc;}
      );

    # Generate devShells for each stdenvOverride
    # {
    #   default = {
    #     aarch64-linux = {
    #       fooPackage = "<foo devShell";
    #       barPackage = "<bar devShell";
    #     };
    #     x86_64-linux = {
    #       ...
    #     };
    #   };
    #   clang = {
    #     ...
    #   };
    # }
    mkDevShellsEachStdenvOverride = devShellFunc:
      mapAttrs (
        _: stdenvOverride:
          mkDevShellsEachSystem (pkgs: pkg:
            devShellFunc {
              inherit pkgs pkg;
              mkShellOverride = stdenvOverride pkgs;
            })
      )
      stdenvOverrides;

    devShellFunctions = rec {
      cDevShells = {
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

      mesonDevShells = {
        pkgs,
        pkg,
        mkShellOverride ? {},
        extraPackages ? [],
        shellHookPre ? "",
      }:
        cDevShells {
          inherit pkgs pkg mkShellOverride extraPackages;
          shellHookPre =
            shellHookPre
            + ''
              ln -s ./build/compile_commands.json
              meson setup build
              ninja -C build
            '';
        };
    };
  in
    # Generate devShells for each devShellFunc
    # {
    #   fooDevShells = {
    #     default = {
    #       aarch64-linux = {
    #         fooPackage = "<foo devShell";
    #         barPackage = "<bar devShell";
    #       };
    #       x86_64-linux = {
    #         ...
    #       };
    #     };
    #     clang = {
    #       ...
    #     };
    #   };
    #   barDevShells = ...
    # }
    mapAttrs (
      _: devShellFunc:
        mkDevShellsEachStdenvOverride devShellFunc
    )
    devShellFunctions;
}
