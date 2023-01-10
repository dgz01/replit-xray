{ pkgs }: {
    deps = [
        pkgs.qrencode.bin
        pkgs.jq
        pkgs.busybox
        pkgs.bashInteractive
        pkgs.man
    ];
}