{ name, lib, pkgs, quadlet-nix, ... }:
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
  imports = [
    quadlet-nix.homeManagerModules.quadlet
  ];

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

  home.packages = with pkgs; let
    emacs-shell = pkgs.writeShellScriptBin "emacs-shell" ''
      PROJECT_NAME=''${1:?}
      PROJECT_DIR=$HOME/projects/$PROJECT_NAME
      export __NIXOS_SET_ENVIRONMENT_DONE=1
      cd $PROJECT_DIR
      exec nix-shell --run "SHELL=${pkgs.zsh}/bin/zsh exec emacs"
    '';
  in [
    alacritty
    emacs
    emacs-shell
    grim
    rofi
    slurp
    wl-clipboard
  ];

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

      bindkey '^R' history-incremental-pattern-search-backward
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

  wayland.windowManager.sway = {
    enable = true;

    config = rec {
      modifier = "Mod4";
      left = "j";
      down = "k";
      up = "l";
      right = "semicolon";

      output = {
        HEADLESS-1 = {
          resolution = "1920x1080";
        };
      };

      menu = "rofi -show combi -modes combi -combi-modes 'drun,run,ssh' -theme solarized";

      bars = [];

      input."type:keyboard" = {
        xkb_layout = "us,ua";
        xkb_options = "grp:caps_toggle";
      };

      terminal = "alacritty";

      fonts = {
        names = [ "pango" ];
        style = "monospace";
        size = 10.0;
      };

      keybindings = lib.mkOptionDefault {
        "Mod4+Print" = "exec grim -g \"$(slurp)\" - | wl-copy";
      };
    };
  };
  systemd.user.services.sway-headless = {
    Unit.Description = "Headless Sway";

    Service = {
      # Launch via a login shell so sway inherits the full NixOS session
      # environment (/etc/profile -> /etc/set-environment). This sets
      # __NIXOS_SET_ENVIRONMENT_DONE=1, which stops descendant shells from
      # re-sourcing set-environment and clobbering vars like LD_LIBRARY_PATH
      # (e.g. a nix-shell override from emacs-shell).
      # ExecStart = "${pkgs.bash}/bin/bash -lc '${pkgs.sway}/bin/sway'";
      ExecStart = "${pkgs.sway}/bin/sway";
      Restart = "always";

      Environment = [
        "WLR_BACKENDS=headless"
        "WLR_LIBINPUT_NO_DEVICES=1"
        "PULSE_SERVER=unix:/run/user/1000/pulse/native"
      ];
    };

    Install.WantedBy = [ "default.target" ];
  };
  systemd.user.services.wayvnc = {
    Unit = {
      Description = "WayVNC";
    };

    Service = {
      ExecStart = "${pkgs.wayvnc}/bin/wayvnc --output=HEADLESS-1 127.0.0.1";
      Restart = "always";
    };

    Install.WantedBy = [ "default.target" ];
  };
  programs.waybar = {
    enable = true;

    systemd = {
      enable = true;
      target = "sway-session.target";
    };

    style = ''
      @import "${pkgs.waybar}/etc/xdg/waybar/style.css";

      * {
        font-family: LiberationMono;
        font-size: 13px;
      }

      #custom-gpu {
        padding: 0 10px;
        background-color: #2980b9;
        color: #ffffff;
      }

      #language {
        background-color: transparent;
        font-size: 16px;
        font-weight: bold;
        color: white;
      }
    '';
    
    settings.main = {
      position = "bottom";
      height = 24;

      modules-left = [
        "sway/workspaces"
        "sway/mode"
        "sway/language"
      ];
      modules-right = [
        "disk#root"
        "disk#home"
        "disk#media-var"
        "memory"
        "cpu"
        "temperature#tccd1"
        "temperature#tccd2"
        "custom/gpu"
        "clock#date"
        "clock#time"
      ];

      "sway/language" = {
        on-click = "swaymsg input '*' xkb_switch_layout next";
      };

      "disk#root" = {
        format = "/ {percentage_used}%";
        path = "/";
      };
      "disk#home" = {
        format = "/home {percentage_used}%";
        path = "/home";
      };
      "disk#media-var" = {
        format = "/media/var {percentage_used}%";
        path = "/media/var";
      };

      memory = {
        interval = 5;
        format = "RAM {percentage}%";
      };
      
      cpu = {
        interval = 2;
        format = "CPU {usage}%";
      };

      "temperature#tccd1" = {
        hwmon-path = "/sys/class/hwmon/hwmon5/temp3_input";
        interval = 5;
      };
      "temperature#tccd2" = {
        hwmon-path = "/sys/class/hwmon/hwmon5/temp4_input";
        interval = 5;
      };

      "custom/gpu" = {
        exec = "${pkgs.python313}/bin/python ${./waybar-gpu-module.py} /sys/class/drm/card1/device";
        return-type = "json";
        format = "{text}";
      };
      
      "clock#date" = {
        format = "{:%d %B %a}";
        tooltip-format = "<tt>{calendar}</tt>";
      };
      "clock#time" = {
        format = "{:%H:%M:%S}";
        interval = 1;
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

  # TODO: Configure hermes agent
  # virtualisation.quadlet.containers = {
  #   hermes-agent = {
  #     autoStart = true;
  #     serviceConfig = {
  #       RestartSec = "10";
  #       Restart = "always";
  #     };
  #     containerConfig = {
  #       image = "docker.io/nousresearch/hermes-agent:v2026.6.5";
  #       userns = "keep-id";
  #       volumes = [
  #         "/home/alexk/.hermes:/opt/data"
  #       ];
  #     };
  #   };
  # };

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
