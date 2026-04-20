;;; akai-bot.el --- akai's IdleRPG gikopoi bot -*- lexical-binding: t; coding: utf-8 -*-
;;; Commentary:
;; Thin wrapper: loads all RPG modules, hooks into gikopoi events,
;; manages the barter tick timer, and provides akai-bot-connect.
;;; Code:

(require 'gikopoi)
(require 'system)
(require 'classes)
(require 'battle)
(require 'barter)
(require 'commands)


;; ---------------------------------------------------------------------------
;; Bot identity

(defcustom akai-bot-name "idleRP"
  "Username the bot logs in as (overridden by run-akai-bot.el from tripcode.gpg)."
  :group 'gikopoi :type 'string)

(defcustom akai-bot-character "giko"
  "Sprite character ID the bot uses."
  :group 'gikopoi :type 'string)

(defcustom akai-bot-server "play.gikopoi.com"
  "Gikopoi server the bot connects to."
  :group 'gikopoi :type 'string)

(defcustom akai-bot-area "for"
  "Area the bot joins on the server (e.g. \"for\", \"gen\", \"vip\")."
  :group 'gikopoi :type 'string)

(defcustom akai-bot-password nil
  "Server password, or nil if the server requires none."
  :group 'gikopoi :type '(choice (const nil) string))


;; ---------------------------------------------------------------------------
;; Barter tick

(defcustom akai-bot-tick-interval 3600
  "Seconds between passive ticks (barter gold, advance checks)."
  :group 'gikopoi :type 'natnum)

(defcustom akai-bot-barter-gold-amount 75
  "Gold awarded to each barter-mode player per tick."
  :group 'gikopoi :type 'natnum)

(defvar akai-bot--tick-timer nil
  "Timer object for the passive tick. Managed by `akai-bot-start-tick-timer'.")

(defun akai-bot--tick ()
  "Award barter gold to barter-mode players and check pending job advances."
  (when (and (boundp 'gikopoi-current-room) gikopoi-current-room)
    (let ((names (mapcar (lambda (u)
                           (substring-no-properties (gikopoi-user-name u)))
                         (gikopoi-room-users gikopoi-current-room))))
      (dolist (name names)
        (when-let ((p (rpg-get-player name)))
          (when-let ((msg (rpg-check-pending-advance p)))
            (akai-bot-say msg))
          (when (eq (rpg-pget p 'mode) 'barter)
            (rpg-add-gold p akai-bot-barter-gold-amount)
            (rpg-save-db)
            (akai-bot-say (format "[BARTER] %s earned %dg from their shop. (total: %dg)"
                                  name akai-bot-barter-gold-amount
                                  (or (rpg-pget p 'gold) 0)))))))))

(defun akai-bot-start-tick-timer ()
  "Start (or restart) the passive tick timer."
  (when (timerp akai-bot--tick-timer) (cancel-timer akai-bot--tick-timer))
  (setq akai-bot--tick-timer
        (run-at-time akai-bot-tick-interval akai-bot-tick-interval
                     #'akai-bot--tick)))

(defun akai-bot-stop-tick-timer ()
  "Cancel the passive tick timer if running."
  (when (timerp akai-bot--tick-timer)
    (cancel-timer akai-bot--tick-timer)
    (setq akai-bot--tick-timer nil)))


;; ---------------------------------------------------------------------------
;; Hourly shout

(defcustom akai-bot-shout-interval 3600
  "Seconds between hourly room announcements."
  :group 'gikopoi :type 'natnum)

(defvar akai-bot--shout-timer nil
  "Timer object for the hourly shout. Managed by `akai-bot-start-shout-timer'.")

(defun akai-bot--shout ()
  "Announce bot info, commands, and contact to the room."
  (akai-bot-say "*** GIKOPOI EMACS GRAPHICS CLIENT SUMMER 2026 *** IdleRPG bot active! Type $help for commands. Feedback: akai@unluckylisp.com"))

(defun akai-bot-start-shout-timer ()
  "Start (or restart) the hourly shout timer.
Fires once 10 seconds after joining (to let the connection settle),
then repeats every `akai-bot-shout-interval' seconds."
  (when (timerp akai-bot--shout-timer) (cancel-timer akai-bot--shout-timer))
  (run-at-time 10 nil #'akai-bot--shout)
  (setq akai-bot--shout-timer
        (run-at-time akai-bot-shout-interval akai-bot-shout-interval
                     #'akai-bot--shout)))

(defun akai-bot-stop-shout-timer ()
  "Cancel the hourly shout timer if running."
  (when (timerp akai-bot--shout-timer)
    (cancel-timer akai-bot--shout-timer)
    (setq akai-bot--shout-timer nil)))


;; ---------------------------------------------------------------------------
;; Bot output

(defun akai-bot-say (text)
  "Send TEXT to the current Gikopoi room as the bot, then clear the bubble."
  (when (and (boundp 'gikopoi-socket)
             (websocket-openp gikopoi-socket))
    (gikopoi-send text t)))


;; ---------------------------------------------------------------------------
;; Gikopoi event hook

(defun akai-bot--on-server-msg (id message)
  "Advice run after server-msg events to dispatch RPG commands.
Ignores messages sent by the bot itself (compared by user ID, not name,
since the server transforms #tripcode to ◆tripcode)."
  (unless (equal id gikopoi-current-user-id)
    (when-let ((user (gikopoi-user-by-id id)))
      (let* ((raw  (substring-no-properties (gikopoi-user-name user)))
             (name (if (string-empty-p raw) "Anonymous" raw)))
        (rpg-dispatch name message)))))


;; ---------------------------------------------------------------------------
;; Enable / disable

(defun akai-bot-enable ()
  "Load the player DB, hook into server-msg events, and start all timers."
  (rpg-load-db)
  (add-function :after (gikopoi-event-fn 'server-msg) #'akai-bot--on-server-msg)
  (akai-bot-start-tick-timer)
  (akai-bot-start-shout-timer)
  (message "akai-bot enabled — %d players loaded." (length rpg--players)))

(defun akai-bot-stop-all-timers ()
  "Cancel the tick timer, shout timer, and all per-player battle timers."
  (akai-bot-stop-tick-timer)
  (akai-bot-stop-shout-timer)
  (rpg-stop-all-battle-timers))

(defun akai-bot-disable ()
  "Remove the server-msg hook and stop all timers."
  (remove-function (gikopoi-event-fn 'server-msg) #'akai-bot--on-server-msg)
  (akai-bot-stop-all-timers)
  (message "akai-bot disabled."))


;; ---------------------------------------------------------------------------
;; Connect

;;;###autoload
(defun akai-bot-connect ()
  "Connect to Gikopoi as the akai-bot with no interactive prompts.
Server, area, name, and character are taken from the akai-bot-* defcustoms.
Room is always auto-selected as the most populated room on the server."
  (interactive)
  (let* ((server akai-bot-server)
         (port   gikopoi-default-port)
         (area   akai-bot-area)
         (room   "bar_st"))
    (akai-bot-enable)
    (add-hook 'gikopoi-quit-functions #'akai-bot-stop-all-timers)
    (gikopoi server port area room
             akai-bot-name akai-bot-character akai-bot-password)))


(provide 'akai-bot)
;;; akai-bot.el ends here
