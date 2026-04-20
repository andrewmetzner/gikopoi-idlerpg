;;; battle.el --- IdleRPG combat engine -*- lexical-binding: t; coding: utf-8 -*-
;;; Commentary:
;; Monsters, combat simulation, battle-mode per-player timers.
;;; Code:

(require 'system)
(require 'classes)


;; ---------------------------------------------------------------------------
;; Monster definitions

(defconst rpg--monsters
  '(;; --- Beginner zone (lv 1-9) ---
    (slime
     :name "Slime" :min-level 1 :max-level 8
     :hp 30 :atk 5 :def 1
     :xp 15 :gold-min 1 :gold-max 5)

    (orange-mushroom
     :name "Orange Mushroom" :min-level 2 :max-level 9
     :hp 45 :atk 7 :def 2
     :xp 22 :gold-min 2 :gold-max 8)

    (pig
     :name "Pig" :min-level 4 :max-level 9
     :hp 60 :atk 10 :def 3
     :xp 30 :gold-min 3 :gold-max 12)

    ;; --- 1st-job zone (lv 10-29) ---
    (zombie
     :name "Zombie" :min-level 10 :max-level 24
     :hp 160 :atk 25 :def 8
     :xp 85 :gold-min 10 :gold-max 30)

    (skeleton
     :name "Skeleton" :min-level 15 :max-level 29
     :hp 220 :atk 35 :def 12
     :xp 120 :gold-min 15 :gold-max 45)

    (orc
     :name "Orc" :min-level 20 :max-level 35
     :hp 300 :atk 45 :def 18
     :xp 175 :gold-min 20 :gold-max 65)

    ;; --- 2nd-job zone (lv 30-69) ---
    (troll
     :name "Troll" :min-level 30 :max-level 55
     :hp 550 :atk 70 :def 32
     :xp 320 :gold-min 40 :gold-max 110)

    (dark-mage
     :name "Dark Mage" :min-level 35 :max-level 60
     :hp 450 :atk 88 :def 22
     :xp 400 :gold-min 50 :gold-max 130)

    (stone-golem
     :name "Stone Golem" :min-level 45 :max-level 69
     :hp 750 :atk 80 :def 50
     :xp 480 :gold-min 65 :gold-max 160)

    ;; --- 3rd-job zone (lv 70-119) ---
    (dragon
     :name "Dragon" :min-level 70 :max-level 100
     :hp 1600 :atk 160 :def 85
     :xp 1300 :gold-min 160 :gold-max 420)

    (demon-lord
     :name "Demon Lord" :min-level 80 :max-level 115
     :hp 2800 :atk 210 :def 110
     :xp 2800 :gold-min 280 :gold-max 650)

    (ancient-golem
     :name "Ancient Golem" :min-level 90 :max-level 119
     :hp 4500 :atk 270 :def 145
     :xp 5500 :gold-min 450 :gold-max 1100)

    ;; --- 4th-job zone (lv 120+) ---
    (chaos-dragon
     :name "Chaos Dragon" :min-level 120 :max-level 150
     :hp 8000 :atk 380 :def 200
     :xp 9000 :gold-min 700 :gold-max 1800)

    (arch-demon
     :name "Arch Demon" :min-level 135 :max-level 175
     :hp 14000 :atk 480 :def 260
     :xp 18000 :gold-min 1200 :gold-max 3000)

    (world-tree
     :name "World Tree" :min-level 150 :max-level 200
     :hp 22000 :atk 580 :def 320
     :xp 35000 :gold-min 2000 :gold-max 5000))
  "Monster definitions: (symbol :key val ...).")

(defun rpg-monster-get (mid key)
  (plist-get (cdr (assq mid rpg--monsters)) key))

(defun rpg-monsters-for-level (level)
  "List of monster symbols valid for LEVEL."
  (mapcar #'car
          (seq-filter (lambda (e)
                        (let ((mn (plist-get (cdr e) :min-level))
                              (mx (plist-get (cdr e) :max-level)))
                          (and (<= mn level) (>= mx level))))
                      rpg--monsters)))

(defun rpg-pick-monster (level)
  "Pick a random monster symbol for LEVEL."
  (let ((pool (rpg-monsters-for-level level)))
    (when pool (nth (random (length pool)) pool))))

;; ---------------------------------------------------------------------------
;; Combat simulation

(defun rpg-simulate-combat (player mid)
  "Simulate one hour of fighting monster MID.
Returns plist: :kills :xp :gold :monster-name."
  (let* ((p-atk        (max (or (rpg-pget player 'atk) 0)
                             (or (rpg-pget player 'matk) 0)))
         (luk          (or (rpg-pget player 'luk) 4))
         (m-hp         (rpg-monster-get mid :hp))
         (m-def        (rpg-monster-get mid :def))
         (luk-mult     (+ 1.0 (* luk 0.002)))
         (p-dmg        (max 1 (round (* (max 1 (- p-atk (/ m-def 2.0))) luk-mult))))
         (rounds-to-kill (ceiling (/ (float m-hp) p-dmg)))
         (kills        (max 0 (floor (/ 60.0 rounds-to-kill))))
         (total-xp     (* kills (rpg-monster-get mid :xp))))
    (list :kills kills
          :xp   total-xp
          :monster-name (rpg-monster-get mid :name))))

(defun rpg-apply-combat (player result)
  "Apply combat RESULT to PLAYER. Returns list of chat announcement strings."
  (let* ((kills (plist-get result :kills))
         (xp    (plist-get result :xp))
         (mname (plist-get result :monster-name))
         (name  (rpg-pget player 'name))
         messages)
    (when (> kills 0)
      (let ((lvl-msgs (rpg-add-xp player xp)))
        (push (format "[BATTLE] %s defeated %d× %s! +%d XP"
                      name kills mname xp)
              messages)
        (dolist (m lvl-msgs) (push m messages))))
    (rpg-save-db)
    (nreverse messages)))


;; ---------------------------------------------------------------------------
;; Battle-mode timers

(defcustom rpg-battle-interval 60
  "Seconds between auto-battles in battle mode."
  :group 'gikopoi :type 'natnum)

(defvar rpg--battle-timers nil
  "Alist of (player-name . timer).")

(defun rpg--battle-tick (player-name)
  (let ((player (rpg-get-player player-name)))
    (when (and player (eq (rpg-pget player 'mode) 'battle))
      (let ((mid (rpg-pick-monster (or (rpg-pget player 'level) 1))))
        (if (null mid)
            (when (fboundp 'akai-bot-say)
              (akai-bot-say
               (format "[BATTLE] %s: no monsters found for your level." player-name)))
          (let ((msgs (rpg-apply-combat player (rpg-simulate-combat player mid))))
            (when (fboundp 'akai-bot-say)
              (dolist (m msgs) (akai-bot-say m)))))))))

(defun rpg-battle-start (player-name)
  (rpg-battle-stop player-name)
  (push (cons player-name
              (run-at-time rpg-battle-interval rpg-battle-interval
                           #'rpg--battle-tick player-name))
        rpg--battle-timers))

(defun rpg-battle-stop (player-name)
  (when-let ((cell (assoc player-name rpg--battle-timers #'string-equal)))
    (cancel-timer (cdr cell))
    (setq rpg--battle-timers
          (cl-remove player-name rpg--battle-timers
                     :test #'string-equal :key #'car))))

(defun rpg-stop-all-battle-timers ()
  (dolist (c rpg--battle-timers) (cancel-timer (cdr c)))
  (setq rpg--battle-timers nil))

(defun rpg-set-mode (player mode)
  "Set PLAYER's mode (battle/barter). Manages timers."
  (let ((name (rpg-pget player 'name))
        (old  (rpg-pget player 'mode)))
    (when (eq old 'battle) (rpg-battle-stop name))
    (rpg-pset player 'mode mode)
    (when (eq mode 'battle) (rpg-battle-start name))
    (rpg-save-db)))


(provide 'battle)
;;; battle.el ends here
