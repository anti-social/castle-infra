{ config, pkgs, ... }:
let
  # doom-emacs = pkgs.callPackage nix-doom-emacs {
  #   doomPrivateDir = ./doom.d;
  # };
  doom-emacs = pkgs.callPackage (pkgs.fetchFromGitHub {
    owner = "nix-community";
    repo = "nix-doom-emacs";
    rev = "5a323e4a17429dbfe9f4fc5fffbe7b2fdeb368fc";
    sha256 = "lvl1ww+QSlZbqRTBKZkd5Big5MZCYXhSaZPZYkZBu0o=";
    #url = https://github.com/nix-community/nix-doom-emacs/archive/master.tar.gz;
  }) {
    doomPrivateDir = ./doom.d;  # Directory containing your config.el, init.el
                                # and packages.el files
    # doomPackageDir = pkgs.linkFarm "doom-packages-dir" [
    #   {
    #     name = "init.el";
    #     path = ./doom.d/init.el;
    #   }
    #   {
    #     name = "packages.el";
    #     path = ./doom.d/packages.el;
    #   }
    #   {
    #     name = "config.el";
    #     path = pkgs.emptyFile;
    #   }
    # ];
  };
in {
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "alexk";
  home.homeDirectory = "/home/alexk";

  home.packages = [ doom-emacs ];

  programs.git = {
    enable = true;
    userEmail = "kovalidis@gmail.com";
    userName = "Oleksandr Koval";
  };

  programs.zsh = {
    enable = true;
    enableAutosuggestions = true;
    defaultKeymap = "emacs";
    history = {
      save = 50000;
      size = 50000;
    };
    initExtra = ''
      autoload -U select-word-style && select-word-style bash
      export WORDCHARS=""
    '';
    prezto = {
      enable = true;
      prompt = {
        pwdLength = "long";
        # showReturnVal = true;
      };
    };
  };

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "22.11";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
