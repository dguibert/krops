let
  lib = import ../../lib;
in

{ exec, nix, openssh, populate, writeDash }: rec {

  build = target:
    exec "rebuild.${target.host}" rec {
      filename = "${openssh}/bin/ssh";
      argv = [
        filename
      ] ++ lib.optionals (target.user != null) [ "-l" target.user ]
        ++ lib.optionals (target.port != null) [ "-p" target.port ]
      ++ [ "-t"
        target.host
        (lib.concatStringsSep " " [
          "nix build"
          "-I ${lib.escapeShellArg target.path}"
          "--no-link -f '<nixpkgs/nixos>'"
          "config.system.build.toplevel"
        ])
      ];
    };

  rebuild = args: target:
    exec "rebuild.${target.host}" rec {
      filename = "${openssh}/bin/ssh";
      argv = [
        filename
      ] ++ lib.optionals (target.user != null) [ "-l" target.user ]
        ++ lib.optionals (target.port != null) [ "-p" target.port ]
      ++ [ "-t"
        target.host
        "nixos-rebuild -I ${lib.escapeShellArg target.path} ${
          lib.concatMapStringsSep " " lib.escapeShellArg args
        }"
      ];
    };

  writeDeploy = name: { force ? false, source, target }: let
    target' = lib.mkTarget target;
  in
    writeDash name ''
      set -efu
      ${populate { inherit force source; target = target'; }}
      ${build target'}
      ${rebuild ["switch"] target'}
    '';

  writeTest = name: { force ? false, source, target }: let
    target' = lib.mkTarget target;
  in
    assert lib.isLocalTarget target';
    writeDash name ''
      set -efu
      ${populate { inherit force source; target = target'; }} >&2
      NIX_PATH=${lib.escapeShellArg target'.path} \
      ${nix}/bin/nix-build \
          -A system \
          --keep-going \
          --no-out-link \
          --show-trace \
          '<nixpkgs/nixos>'
    '';

}
