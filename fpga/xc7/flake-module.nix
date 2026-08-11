# xc7 leg: minimal yosys + VTR(VPR) + fpga-assembler flow for Artix-7.
# Enter with `nix develop .#xc7`, then `make` in this directory.
{ ... }:
{
  perSystem =
    { inputs', pkgs, ... }:
    let
      # Schema the interchange build normally wgets from GitHub; pre-placed
      # in the build dir so the download rule never runs (no sandbox network).
      javaCapnp = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/capnproto/capnproto-java/master/compiler/src/main/schema/capnp/java.capnp";
        sha256 = "1azg78iw5njvqfmhfrwklkpya3pvfh1h5rnzqwkaq1psky2qvi5b";
      };

      fpga-as = inputs'.fpga-as.packages.default;

      # VPR + genfasm from the f4pga fork of VTR, pinned to the commit the
      # 2022-09-20 arch-defs artifacts were built against (conda vtr-optimized
      # 8.0.0_5699_g25e723a24). The binary rr_graph format must match.
      # gcc 13: 2022-era code (plus vendored capnproto); gcc 15's C++20
      # default and stricter headers reject it wholesale.
      vtr = pkgs.gcc13Stdenv.mkDerivation {
        pname = "vtr-f4pga";
        version = "8.0.0+g25e723a24";
        src = pkgs.fetchFromGitHub {
          owner = "SymbiFlow";
          repo = "vtr-verilog-to-routing";
          rev = "25e723a24aa0ae7a0061cd89dd84b1fb62afcc09";
          sha256 = "0h0fp7c3w56vknbyiwlsgkcz3h1h063iygyd3qaapbmh73spqwmb";
        };
        nativeBuildInputs = with pkgs; [ cmake bison flex pkg-config python3 wget ];
        buildInputs = with pkgs; [ zlib ];
        env.CMAKE_POLICY_VERSION_MINIMUM = "3.5";
        # Missing <cstdint>/<sstream> includes in a few files (gcc >= 13).
        env.CXXFLAGS = "-include cstdint -include sstream";
        cmakeFlags = [
          "-DCMAKE_BUILD_TYPE=Release"
          "-DVPR_USE_EZGL=off"
          "-DWITH_BLIFEXPLORER=off"
        ];
        preBuild = ''
          mkdir -p libs/libvtrcapnproto/schema/capnp
          cp ${javaCapnp} libs/libvtrcapnproto/schema/capnp/java.capnp
        '';
        buildPhase = "runHook preBuild; make -j$NIX_BUILD_CORES vpr genfasm";
        installPhase = ''
          mkdir -p $out/bin
          cp vpr/vpr $out/bin/
          cp utils/fasm/genfasm $out/bin/
        '';
      };

      pluginsSrc = pkgs.fetchFromGitHub {
        owner = "chipsalliance";
        repo = "yosys-f4pga-plugins";
        rev = "e7070ca645d1e33f7fadb4f3a027c77c83641cae";
        sha256 = "07faaddchmhg3giaazanj2n598545yi8an8n2hfnc0ib7nykiz1v";
      };

      # Yosys pinned to the f4pga-era version, with the plugins synth.tcl
      # loads (xdc, fasm, params, sdc, design_introspection) built into its
      # plugin dir.
      yosys-f4pga = pkgs.stdenv.mkDerivation {
        pname = "yosys-f4pga";
        version = "0.27+g0f5e7c244";
        src = pkgs.fetchFromGitHub {
          owner = "YosysHQ";
          repo = "yosys";
          rev = "0f5e7c244df1bb0d4b41bd54d4d5791e653ed448";
          sha256 = "088gdy23q2zmh99cyb3r2klarrmcbkbbjvh9q70kkmz2l2afpp17";
        };
        nativeBuildInputs = with pkgs; [ pkg-config bison flex ];
        buildInputs = with pkgs; [ readline zlib tcl libffi python3 ];
        # 2023 code vs gcc 15: vendored json11 lacks <cstdint>.
        env.CXXFLAGS = "-include cstdint";
        configurePhase = "make config-gcc";
        makeFlags = [ "PREFIX=$(out)" "ABCEXTERNAL=${pkgs.abc-verifier}/bin/abc" ];
        enableParallelBuilding = true;
        postInstall = ''
          # yosys-config ships with #!/usr/bin/env bash; the automatic shebang
          # fixup only runs after postInstall, so patch it now — the plugin
          # builds shell out to it for their compile flags.
          patchShebangs $out/bin
          cp -r ${pluginsSrc} plugins
          chmod -R u+w plugins
          patchShebangs plugins
          for p in fasm xdc params sdc design_introspection; do
            # SHELL override: the common makefile hardcodes /usr/bin/env bash.
            make -C plugins/''${p}-plugin install YOSYS_PATH=$out SHELL=$(type -p bash)
          done
        '';
      };

      # Architecture data: arch.timing.xml + binary rr graph + pinmaps for the
      # xc7a50t die (the xc7a35t parts are binned 50t dies) + xc7 techmaps.
      arch-defs = pkgs.stdenv.mkDerivation {
        pname = "symbiflow-arch-defs-xc7";
        version = "007d1c1";
        srcs = [
          (pkgs.fetchurl {
            url = "https://storage.googleapis.com/symbiflow-arch-defs/artifacts/prod/foss-fpga-tools/symbiflow-arch-defs/continuous/install/20220920-124259/symbiflow-arch-defs-install-xc7-007d1c1.tar.xz";
            sha256 = "0rcaml2fqiwd9qllq9c4ha3l4paig3prg84xx6ss1lmqz89s52wd";
          })
          (pkgs.fetchurl {
            url = "https://storage.googleapis.com/symbiflow-arch-defs/artifacts/prod/foss-fpga-tools/symbiflow-arch-defs/continuous/install/20220920-124259/symbiflow-arch-defs-xc7a50t_test-007d1c1.tar.xz";
            sha256 = "0kc31mi8l5q74c3a6096iidzr2isf1d8q8c2lyxfibq3hnqdibvx";
          })
        ];
        dontUnpack = true;
        installPhase = ''
          mkdir -p $out
          for s in $srcs; do tar xJf $s -C $out; done
        '';
      };

      # prjxray database: tile grid + segbits. Consumed by fpga-as, and
      # part.json by synth.tcl.
      prjxray-db = pkgs.fetchFromGitHub {
        owner = "f4pga";
        repo = "prjxray-db";
        rev = "0a0addedd73e7e4139d52a6d8db4258763e0f1f3";
        sha256 = "19zbp3ybxj0ivr54zgdr24h7hrsg8a5bxzrpqwf5jfpysikg8kbi";
      };
    in
    {
      packages = {
        inherit vtr yosys-f4pga arch-defs;
      };

      devShells.xc7 = pkgs.mkShell {
        # The whole flow: yosys -> vpr -> genfasm -> fpga-as. python3 carries
        # lxml for the vendored ioplace scripts (they parse the .net XML);
        # everything else in scripts/ is stdlib-only.
        packages = [ vtr yosys-f4pga (pkgs.python3.withPackages (ps: [ ps.lxml ])) pkgs.openfpgaloader fpga-as ];
        ARCH_DIR = "${arch-defs}/share/f4pga/arch/xc7a50t_test";
        TECHMAP_PATH = "${arch-defs}/share/f4pga/techmaps/xc7_vpr/techmap";
        PRJXRAY_DB = "${prjxray-db}";
      };
    };
}
