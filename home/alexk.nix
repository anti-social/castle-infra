{ name, lib, pkgs, ... }:
let
  zshThemes = {
    dell-laptop = "agnoster";
    pc = "alanpeabody";
  };

  # doom-emacs = pkgs.callPackage nix-doom-emacs {
  #   doomPrivateDir = ./doom.d;
  # };
  # doom-emacs = pkgs.callPackage (pkgs.fetchFromGitHub {
  #   owner = "nix-community";
  #   repo = "nix-doom-emacs";
  #   rev = "5a323e4a17429dbfe9f4fc5fffbe7b2fdeb368fc";
  #   sha256 = "lvl1ww+QSlZbqRTBKZkd5Big5MZCYXhSaZPZYkZBu0o=";
  # }) {
  #   doomPrivateDir = ./doom.d;  # Directory containing your config.el, init.el
  #                               # and packages.el files
  #   doomPackageDir = pkgs.linkFarm "doom-packages-dir" [
  #     {
  #       name = "init.el";
  #       path = ./doom.d/init.el;
  #     }
  #     {
  #       name = "packages.el";
  #       path = ./doom.d/packages.el;
  #     }
  #     {
  #       name = "config.el";
  #       path = pkgs.emptyFile;
  #     }
  #   ];
  # };
in {
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "alexk";
  home.homeDirectory = "/home/alexk";
  home.sessionPath = [
    "/home/alexk/.local/bin"
  ];
  home.sessionVariables = {
    LETS_CONTAINER_ENGINE = "podman";
    CROSS_CONTAINER_ENGINE = "podman";
  };

  # home.packages = [ doom-emacs ];

  programs.zsh = {
    enable = true;
    autosuggestion = {
      enable = true;
    };
    defaultKeymap = "emacs";
    history = {
      expireDuplicatesFirst = true;
      save = 50000;
      share = true;
      size = 50000;
    };
    initContent = ''
      # Bash like navigation
      autoload -U select-word-style && select-word-style bash
      export WORDCHARS=""
    '';
    oh-my-zsh = {
      enable = true;
      plugins = [ "ssh-agent" "sudo" ];
      theme = zshThemes.${name};
    };
    # prezto = {
    #   enable = true;
    #   prompt = {
    #     pwdLength = "long";
    #     # showReturnVal = true;
    #   };
    # };
  };

  programs.starship = {
    enable = true;
    settings = lib.mkMerge [
      (builtins.fromTOML
        (builtins.readFile "${pkgs.starship}/share/starship/presets/nerd-font-symbols.toml"
      ))
      {
        add_newline = true;
        character = {
          # success_symbol = "[\\$](green)";
          # error_symbol = "[\\$](bold red)";
        };
        aws = {
          disabled = true;
        };
        cmd_duration = {
          min_time = 0;
          show_milliseconds = true;
        };
        package = {
          disabled = true;
        };
        status = {
          disabled = false;
        };
        time = {
          disabled = false;
        };
      }
    ];
  };

  programs.git = {
    enable = true;
    settings = {
      user.email = "kovalidis@gmail.com";
      user.name = "Alexander Koval";
      alias = {
        ci = "commit";
        co = "checkout";
        ff = "merge --ff-only";
        last = "log -1 HEAD";
        meld = "difftool --dir-diff -t meld";
        st = "status";
        up = "pull --no-stat --ff-only";
      };
    };
  };

  xdg.configFile = {
    "containers/registries.conf".text = ''
      [registries.search]
      registries = ["docker.io"]

      [registries.insecure]
      registries = []

      [registries.block]
      registries = []
    '';
    "containers/policy.json".text = ''
      {
        "default": [
          {"type": "insecureAcceptAnything"}
        ],
        "transports": {
          "docker-daemon": {
            "": [
              {"type": "insecureAcceptAnything"}
            ]
          }
        }
      }
    '';

    "doom" = {
      source = ./doom;
      recursive = true;
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
  home.stateVersion = "23.05";

  # Let Home Manager install and manage itself.
  # programs.home-manager.enable = true;
}
