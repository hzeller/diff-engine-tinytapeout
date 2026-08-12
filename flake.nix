{
  description = "Tiny Tapeout design written in DSLX (google/xls)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    fpga-as = {
      url = "github:lromor/fpga-as";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        # Repo submodules defining their own flake outputs.
        ./fpga/flake-module.nix
      ];

      systems = [ "x86_64-linux" ];

      perSystem =
        { pkgs, ... }:
        let
          xls = pkgs.stdenv.mkDerivation rec {
            pname = "xls";
            version = "v0.0.0-10464-g397e5c562";
            src = pkgs.fetchurl {
              url = "https://github.com/google/xls/releases/download/${version}/xls-${version}-linux-x64.tar.gz";
              sha256 = "1s5yj0zsjhhxw2iyc76sr4k5q6h8vna05lf2fydmd9avsn5nqbxy";
            };
            nativeBuildInputs = [ pkgs.makeWrapper ];
            installPhase = ''
              mkdir -p $out/bin

              # The XLS names are very non-descript, and use underscores.
              # Give them some proper names: xls- prefix, dashes, no _main suffix.
              for f in *_main ; do
                cp $f $out/bin/$(echo xls-$f | sed 's/_main//' | sed 's/_/-/g');
              done

              # dslx binaries don't have the main-suffix anymore, but still
              # punchcard-era underscores.
              cp dslx_ls $out/bin/dslx-ls
              cp dslx_fmt $out/bin/dslx-fmt

              # xls standard library
              mkdir -p $out/lib/xls
              mv xls/dslx $out/lib/xls
            '';
            postFixup = ''
              wrapProgram $out/bin/dslx-ls \
                --add-flags "--stdlib_path=$out/lib/xls/dslx/stdlib"
            '';
          };
        in
        {
          packages.xls = xls;

          devShells.default = pkgs.mkShell {
            packages = [ xls ];
            DSLX_STDLIB_PATH = "${xls}/lib/xls/dslx/stdlib";

            # Possibly ':'-separated more paths to search
            DSLX_PATH = "${xls}/lib";
          };
        };
    };
}
