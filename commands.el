;;; commands.el --- IdleRPG command handlers -*- lexical-binding: t; coding: utf-8 -*-
;;; Commentary:
;; All $cmd handlers and the dispatch table.
;;; Code:

(require 'system)
(require 'classes)
(require 'battle)


;; ---------------------------------------------------------------------------
;; Output helper (bound at runtime by akai-bot.el)

(defun rpg-say (text)
  (when (fboundp 'akai-bot-say) (akai-bot-say text)))

(defun rpg-needs-registration (sender)
  (rpg-say (format "%s: Not registered. Use $register first." sender))
  nil)

(defun rpg-weapon-name (player)
  "Return the weapon name for PLAYER's current job."
  (or (rpg-job-pget (rpg-pget player 'job) :weapon) "Fists"))

(defun rpg-atk-label (player)
  "Return ATK or MATK label + value string for PLAYER."
  (if (rpg--mage-job-p (rpg-pget player 'job))
      (format "MATK:%d" (or (rpg-pget player 'matk) 0))
    (format "ATK:%d" (or (rpg-pget player 'atk) 0))))


;; ---------------------------------------------------------------------------
;; $help

(defun rpg-cmd-help (sender _args)
  (ignore sender)
  (rpg-say (concat "$register | $char | $job | $advance <job> | "
                   "$addstat <stat> [n] | $toggle | "
                   "$upgrade <weapon/armor> | $resetstats | $top | $online")))


;; ---------------------------------------------------------------------------
;; Character

(defun rpg-cmd-register (sender _args)
  (if (rpg-get-player sender)
      (rpg-say (format "%s: Already registered! Use $char." sender))
    (rpg-register-player sender)
    (rpg-say (format "Hello %s! You are a Beginner. Fight monsters for XP, $toggle to switch modes. $help for commands." sender))))

(defun rpg-cmd-char (sender _args)
  (if-let ((p (rpg-get-player sender)))
      (let* ((job      (rpg-pget p 'job))
             (choices  (rpg-job-pget job :advance-choices))
             (err      (rpg-advance-check p))
             (pending  (rpg-pget p 'advance-pending))
             (ready-at (rpg-pget p 'advance-ready-at))
             (adv-hint
              (cond
               (pending
                (let* ((remaining (max 0 (round (- ready-at (float-time)))))
                       (hours   (/ remaining 3600))
                       (minutes (/ (% remaining 3600) 60)))
                  (format "advancing → %s (%dh%dm)"
                          (rpg-job-name pending) hours minutes)))
               ((null choices) "max job")
               ((null err) "job advance ready! $job for more")
               (t (format "next advance: lv%d"
                          (rpg-job-pget job :advance-level))))))
        (rpg-say
         (format "%s [%s Lv.%d %s] STR:%d DEX:%d INT:%d LUK:%d | %s [%s+%d] DEF:%d | XP:%d(+%d) | Gold:%dg | AP:%d | %s"
                 sender
                 (rpg-job-name job)
                 (rpg-pget p 'level)
                 (rpg-pget p 'mode)
                 (rpg-pget p 'str)    (rpg-pget p 'dex)
                 (rpg-pget p 'int)    (rpg-pget p 'luk)
                 (rpg-atk-label p)
                 (rpg-weapon-name p)
                 (or (rpg-pget p 'weapon-upgrades) 0)
                 (rpg-pget p 'def)
                 (rpg-pget p 'xp)     (rpg-xp-to-next p)
                 (or (rpg-pget p 'gold) 0)
                 (or (rpg-pget p 'ap) 0)
                 adv-hint)))
    (rpg-needs-registration sender)))


;; ---------------------------------------------------------------------------
;; Jobs

(defun rpg-cmd-job (sender _args)
  (if-let ((p (rpg-get-player sender)))
      (let* ((job     (rpg-pget p 'job))
             (choices (rpg-job-pget job :advance-choices))
             (lvl     (rpg-pget p 'level))
             (adv-lvl (rpg-job-pget job :advance-level))
             (adv-req (rpg-job-pget job :advance-req))
             (pending  (rpg-pget p 'advance-pending))
             (ready-at (rpg-pget p 'advance-ready-at))
             (lvl-ok   (or (null adv-lvl) (>= lvl adv-lvl)))
             (stat-err (when adv-req
                         (let ((unmet (cl-remove-if
                                       (lambda (r) (>= (or (rpg-pget p (car r)) 0) (cdr r)))
                                       adv-req)))
                           (when unmet
                             (mapconcat (lambda (r)
                                          (format "%s %d (@%d)"
                                                  (upcase (symbol-name (car r)))
                                                  (cdr r)
                                                  (or (rpg-pget p (car r)) 0)))
                                        unmet ", ")))))
             (reqs-unmet (append
                          (when (not lvl-ok) (list (format "lv%d" adv-lvl)))
                          (when stat-err (list stat-err)))))
        (rpg-say
         (format "%s: %s | %s"
                 sender
                 (rpg-job-name job)
                 (cond
                  (pending
                   (let* ((remaining (max 0 (round (- ready-at (float-time)))))
                          (hours   (/ remaining 3600))
                          (minutes (/ (% remaining 3600) 60)))
                     (format "Advancing to %s — %dh%dm remaining."
                             (rpg-job-name pending) hours minutes)))
                  ((null choices) "Max job reached!")
                  (reqs-unmet
                   (format "Need %s → %s"
                           (string-join reqs-unmet ", ")
                           (mapconcat #'rpg-job-name choices " / ")))
                  (t (format "READY! %s"
                             (mapconcat (lambda (j) (format "$advance %s" (symbol-name j)))
                                        choices " / ")))))))
    (rpg-needs-registration sender)))

;; (defun rpg-cmd-classes (_sender _args)
;;   (rpg-say "lv10: warrior/magician/thief/ranger/pirate → lv30: fighter/spearman/page/fp-wizard/il-wizard/cleric/assassin/bandit/bowman/crossbowman/knuckler/shooter → lv70: crusader/dragon-knight/white-knight/fp-mage/il-mage/priest/hermit/chief-bandit/marksman/sniper/frontliner/marauder → lv120: hero/dark-knight/paladin/fp-archmage/il-archmage/bishop/night-lord/shadower/bowmaster/king-sniper/buccaneer/gunslinger"))

(defun rpg-cmd-advance (sender args)
  (if-let ((p (rpg-get-player sender)))
      (if (null args)
          (rpg-cmd-job sender nil)
        (let* ((new-job (intern (downcase (string-trim args))))
               (err     (rpg-start-advance p new-job)))
          (if err
              (rpg-say (format "%s: %s" sender err))
            (rpg-say (format "%s: Advancing to %s! Come back in 24h."
                             sender (rpg-job-name new-job))))))
    (rpg-needs-registration sender)))


;; ---------------------------------------------------------------------------
;; AP / stats

(defun rpg-cmd-addstat (sender args)
  (if-let ((p (rpg-get-player sender)))
      (if (or (null args) (string-empty-p (string-trim args)))
          (rpg-say (format "%s: Usage: $addstat <str/dex/int/luk> [amount]" sender))
        (let* ((parts    (split-string (downcase (string-trim args)) " " t))
               (stat-str (car parts))
               (amount   (if (cadr parts) (string-to-number (cadr parts)) 1))
               (err      (if (<= amount 0)
                             "Amount must be at least 1."
                           (rpg-spend-ap p (intern stat-str) amount))))
          (if err
              (rpg-say (format "%s: %s" sender err))
            (rpg-say (format "%s: +%d %s → STR:%d DEX:%d INT:%d LUK:%d | %s DEF:%d | %d AP left"
                             sender (or (rpg-pget p 'last-ap-spent) amount)
                             (upcase stat-str)
                             (rpg-pget p 'str) (rpg-pget p 'dex)
                             (rpg-pget p 'int) (rpg-pget p 'luk)
                             (rpg-atk-label p) (rpg-pget p 'def)
                             (or (rpg-pget p 'ap) 0))))))
    (rpg-needs-registration sender)))


;; ---------------------------------------------------------------------------
;; Inventory / equipment / consumables



;; ---------------------------------------------------------------------------
;; Toggle mode (battle / barter)

(defun rpg-cmd-toggle (sender _args)
  (if-let ((p (rpg-get-player sender)))
      (if (eq (rpg-pget p 'mode) 'barter)
          (progn (rpg-set-mode p 'battle)
                 (rpg-say (format "%s: Battle mode engaged -- earning XP" sender)))
        (rpg-set-mode p 'barter)
        (rpg-say (format "%s: Barter mode engaged -- earning gold" sender)))
    (rpg-needs-registration sender)))


;; ---------------------------------------------------------------------------
;; Status

(defun rpg-cmd-upgrade (sender args)
  (if-let ((p (rpg-get-player sender)))
      (let ((sub (and args (downcase (string-trim args)))))
        (cond
         ((string-equal sub "weapon")
          (let ((err (rpg-upgrade-slot p 'weapon)))
            (if err
                (rpg-say (format "%s: %s" sender err))
              (rpg-say (format "%s: %s upgraded to +%d! %s"
                               sender (rpg-weapon-name p)
                               (or (rpg-pget p 'weapon-upgrades) 0)
                               (rpg-atk-label p))))))
         ((string-equal sub "armor")
          (let ((err (rpg-upgrade-slot p 'armor)))
            (if err
                (rpg-say (format "%s: %s" sender err))
              (rpg-say (format "%s: Armor upgraded to +%d! DEF:%d"
                               sender (or (rpg-pget p 'armor-upgrades) 0)
                               (rpg-pget p 'def))))))
         (t
          (let* ((alvl  (or (rpg-pget p 'armor-upgrades) 0))
                 (acost (* 50 (1+ alvl))))
            (rpg-say (format "%s: weapon %s (+3 ATK ea) | armor +%d (next: %dg, +2 DEF)"
                             sender
                             (rpg-upgrade-weapon-info p)
                             alvl acost))))))
    (rpg-needs-registration sender)))

(defun rpg-cmd-resetstats (sender _args)
  (if-let ((p (rpg-get-player sender)))
      (let ((err (rpg-resetstats p)))
        (if err
            (rpg-say (format "%s: %s" sender err))
          (rpg-say (format "%s: Stats reset! STR:%d DEX:%d INT:%d LUK:%d | %d AP refunded."
                           sender
                           (rpg-pget p 'str) (rpg-pget p 'dex)
                           (rpg-pget p 'int) (rpg-pget p 'luk)
                           (or (rpg-pget p 'ap) 0)))))
    (rpg-needs-registration sender)))


;; ---------------------------------------------------------------------------
;; Social / meta

(defun rpg-rankings-string ()
  (if (null rpg--players)
      "No players registered yet."
    (let* ((sorted (sort (copy-sequence rpg--players)
                         (lambda (a b)
                           (or (> (rpg-pget a 'level) (rpg-pget b 'level))
                               (and (= (rpg-pget a 'level) (rpg-pget b 'level))
                                    (> (rpg-pget a 'xp) (rpg-pget b 'xp)))))))
           (top (seq-take sorted 5)))
      (concat "Rankings: "
              (string-join
               (cl-loop for i from 1 for p in top
                        collect (format "#%d %s [%s Lv.%d]"
                                        i
                                        (rpg-pget p 'name)
                                        (rpg-job-name (rpg-pget p 'job))
                                        (rpg-pget p 'level)))
               " | ")))))

(defun rpg-cmd-top (_sender _args)
  (rpg-say (rpg-rankings-string)))


(defun rpg-cmd-online (_sender _args)
  (if (not (and (boundp 'gikopoi-current-room) gikopoi-current-room))
      (rpg-say "Not in a room.")
    (let* ((users   (gikopoi-room-users gikopoi-current-room))
           (names   (mapcar (lambda (u)
                              (substring-no-properties (gikopoi-user-name u)))
                            users))
           (playing (seq-filter #'rpg-get-player names)))
      (if (null playing)
          (rpg-say "No registered IdleRPG players online.")
        (rpg-say
         (concat "Online: "
                 (string-join
                  (mapcar (lambda (n)
                            (let ((p (rpg-get-player n)))
                              (format "%s[%s Lv.%d %s]"
                                      n
                                      (rpg-job-name (rpg-pget p 'job))
                                      (rpg-pget p 'level)
                                      (rpg-pget p 'mode))))
                          playing)
                  " ")))))))


;; ---------------------------------------------------------------------------
;; Dispatch

(defconst rpg-commands
  '(("help"       . rpg-cmd-help)
    ("register"   . rpg-cmd-register)
    ("char"       . rpg-cmd-char)
    ("job"        . rpg-cmd-job)
    ("advance"    . rpg-cmd-advance)
    ;; ("classes" . rpg-cmd-classes)
    ("addstat"    . rpg-cmd-addstat)
    ("toggle"     . rpg-cmd-toggle)
    ("upgrade"    . rpg-cmd-upgrade)
    ("resetstats" . rpg-cmd-resetstats)
    ("top"        . rpg-cmd-top)
    ("online"     . rpg-cmd-online))
  "Command dispatch table: (\"name\" . handler-fn).")

(defun rpg-dispatch (sender message)
  "If MESSAGE starts with $, dispatch to appropriate handler."
  (when (string-prefix-p "$" message)
    (let* ((body  (substring message 1))
           (space (string-match " " body))
           (cmd   (downcase (if space (substring body 0 space) body)))
           (args  (when space (string-trim (substring body (1+ space)))))
           (fn    (cdr (assoc cmd rpg-commands #'string-equal))))
      (when fn (funcall fn sender args)))))


(provide 'commands)
;;; commands.el ends here
