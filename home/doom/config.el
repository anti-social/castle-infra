;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets.
(setq user-full-name "Olexandr Koval"
      user-mail-address "kovalidis@gmail.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom. Here
;; are the three important ones:
;;
;; + `doom-font'
;; + `doom-variable-pitch-font'
;; + `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;;
;; They all accept either a font-spec, font string ("Input Mono-12"), or xlfd
;; font string. You generally only need these two:
(setq doom-font (font-spec :family "Liberation Mono" :size 14)
      doom-variable-pitch-font (font-spec :family "Ubuntu" :size 14))

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-one)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; (after! doom-modeline
;;   (setq doom-modeline-persp-name t))

;; Here are some additional functions/macros that could help you configure Doom:
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.
(put 'projectile-ripgrep 'disabled nil)
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages '(list-packages-ext company-restclient restclient ripgrep)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
(put 'downcase-region 'disabled nil)

(setq doom-unreal-buffer-functions '(minibufferp))

;; Never create a new workspace on project switch.
(setq +workspaces-on-switch-project-behavior nil)

(setenv "PATH" (concat (getenv "PATH") ":~/.cargo/bin"))
(setq exec-path (append exec-path '("~/.cargo/bin")))

(setq lsp-clients-kotlin-server-executable
      "/home/alexk/projects/kotlin-language-server/server/build/install/server/bin/kotlin-language-server")

;; Render column indicator
(global-display-fill-column-indicator-mode 1)
(add-hook 'vterm-mode-hook (lambda () (display-fill-column-indicator-mode -1)))

;; Camel case words
(global-subword-mode 1)

;; so-long-minor-mode for compilation buffers
;;(add-hook 'compilation-mode 'so-long-minor-mode)

;; Too slow
;;(+global-word-wrap-mode +1)

;; Use // to comment code block
(add-hook 'c-mode-hook (lambda () (c-toggle-comment-style -1)))

;; Window management
;; (setq display-buffer-base-action
;;   '((display-buffer-reuse-window)))

;; (setq split-height-threshold nil)
(setq split-width-threshold nil)

;; (setq +popup-default-display-buffer-actions nil)

;; Hotkeys
(global-set-key (kbd "C-j") 'newline-and-indent)
(define-key compilation-mode-map (kbd "C-o") nil)
(global-set-key (kbd "C-o") 'next-window-any-frame)

;; (let ((ctrl-j-shortcut (if (display-graphic-p) "C-j" "Ctrl+J")))
;;         (map! :after company-box
;;               :map company-active-map
;;               ctrl-j-shortcut #'company-complete-selection
;;               "<return>" nil)
;; )

;; (use-package! forge
;;   :after magit)

;; Magit Forge
(setq
 forge-alist
 '(("gitlab.evo.dev" "gitlab.evo.dev/api/v4" "gitlab.evo.dev" forge-gitlab-repository)
   ("github.com" "api.github.com" "github.com" forge-github-repository)
   ("gitlab.com" "gitlab.com/api/v4" "gitlab.com" forge-gitlab-repository))
 )

;; Code review
(setq code-review-gitlab-host "gitlab.evo.dev/api")
(setq code-review-gitlab-graphql-host "gitlab.evo.dev/api")

;; Vterm
(setq vterm-toggle-fullscreen-p nil)
;; (add-to-list 'display-buffer-alist
;;              '((lambda (buffer-or-name _)
;;                    (let ((buffer (get-buffer buffer-or-name)))
;;                      (with-current-buffer buffer
;;                        (or (equal major-mode 'vterm-mode)
;;                            (string-prefix-p vterm-buffer-name (buffer-name buffer))))))
;;                 (display-buffer-reuse-window display-buffer-at-bottom)
;;                 ;;(display-buffer-reuse-window display-buffer-in-direction)
;;                 ;;display-buffer-in-direction/direction/dedicated is added in emacs27
;;                 ;;(direction . bottom)
;;                 ;;(dedicated . t) ;dedicated is supported in emacs27
;;                 (reusable-frames . visible)
;;                 (window-height . 0.3)))
