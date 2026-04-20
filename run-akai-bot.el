;;; run-akai-bot.el --- Launch akai-bot -*- lexical-binding: t; coding: utf-8 -*-
;;
;; Entry point. Load this instead of gikopoi.el.
;; Does NOT touch any gikopoi-default-* variables from .emacs.
;;
;; Usage:  M-x load-file RET run-akai-bot.el RET
;; Or:     (load "/path/to/run-akai-bot.el")

(let ((dir (file-name-directory (or load-file-name buffer-file-name))))
  (load (expand-file-name "gikopoi.el"  dir))
  (load (expand-file-name "system.el"   dir))
  (load (expand-file-name "classes.el"  dir))
  (load (expand-file-name "battle.el"   dir))
  (load (expand-file-name "barter.el"   dir))
  (load (expand-file-name "commands.el" dir))
  (load (expand-file-name "akai-bot.el" dir)))

;; Load tripcode from file and build username "Akai#<tripcode>"
(let* ((dir      (file-name-directory (or load-file-name buffer-file-name)))
       (tc-file  (expand-file-name "tripcode.gpg" dir))
       (tripcode (if (file-exists-p tc-file)
                     (string-trim
                      (with-temp-buffer
                        (let ((coding-system-for-read 'utf-8))
                          (insert-file-contents tc-file)) ; EasyPG decrypts, reads as UTF-8
                        (buffer-string)))
                   (error "akai-bot: tripcode.gpg not found at %s" tc-file))))
  (setq akai-bot-name (format "Akai#%s" tripcode)))

;; All bot config lives here — edit to taste:
(setq akai-bot-server    "play.gikopoi.com"
      akai-bot-area      "for"
      akai-bot-character "giko"
      akai-bot-password  nil
      ;; Battle: one fight per hour for players in battle mode
      rpg-battle-interval 3600)

(akai-bot-connect)
