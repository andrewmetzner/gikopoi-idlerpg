;;; classes.el --- MapleStory-style job tree -*- lexical-binding: t; coding: utf-8 -*-
;;; Commentary:
;; Job definitions, stat bonuses, job advancement.
;; Tiers: Beginner(0) → 1st(lv10) → 2nd(lv30) → 3rd(lv70) → 4th(lv120)
;;; Code:

(require 'system)


;; ---------------------------------------------------------------------------
;; Job tree

(defconst rpg--job-tree
  '(;; ===================================================================
    ;; Beginner
    ;; ===================================================================
    (beginner
     :name "Beginner" :tier 0 :weapon "Frying Pan"
     :advance-level 10
     :advance-choices (warrior magician thief ranger pirate))

    ;; ===================================================================
    ;; Warrior paths
    ;; ===================================================================
    (warrior
     :name "Warrior" :tier 1 :weapon "Training Sword"
     :advances-from beginner
     :advance-level 30
     :advance-choices (fighter spearman page)
     :advance-req ((str . 65) (dex . 25))
     :stat-bonus ((str . 30)))

    ;; Path A: Fighter → Crusader → Hero
    (fighter
     :name "Fighter" :tier 2 :weapon "Sword"
     :advances-from warrior
     :advance-level 70
     :advance-choices (crusader)
     :advance-req ((str . 130) (dex . 60))
     :stat-bonus ((str . 15) (dex . 5)))

    (crusader
     :name "Crusader" :tier 3 :weapon "Longsword"
     :advances-from fighter
     :advance-level 120
     :advance-choices (hero)
     :advance-req ((str . 200) (dex . 100))
     :stat-bonus ((str . 20) (dex . 5)))

    (hero
     :name "Hero" :tier 4 :weapon "Hero's Sword"
     :advances-from crusader
     :stat-bonus ((str . 30) (dex . 10)))

    ;; Path B: Spearman → Dragon Knight → Dark Knight
    (spearman
     :name "Spearman" :tier 2 :weapon "Spear"
     :advances-from warrior
     :advance-level 70
     :advance-choices (dragon-knight)
     :advance-req ((str . 130) (dex . 60))
     :stat-bonus ((str . 10) (dex . 5)))

    (dragon-knight
     :name "Dragon Knight" :tier 3 :weapon "Dragon Spear"
     :advances-from spearman
     :advance-level 120
     :advance-choices (dark-knight)
     :advance-req ((str . 200) (dex . 100))
     :stat-bonus ((str . 20)))

    (dark-knight
     :name "Dark Knight" :tier 4 :weapon "Dark Spear"
     :advances-from dragon-knight
     :stat-bonus ((str . 35)))

    ;; Path C: Page → White Knight → Paladin
    (page
     :name "Page" :tier 2 :weapon "Mace"
     :advances-from warrior
     :advance-level 70
     :advance-choices (white-knight)
     :advance-req ((str . 130) (dex . 60))
     :stat-bonus ((str . 10) (dex . 10)))

    (white-knight
     :name "White Knight" :tier 3 :weapon "Holy Mace"
     :advances-from page
     :advance-level 120
     :advance-choices (paladin)
     :advance-req ((str . 200) (dex . 100))
     :stat-bonus ((str . 15) (int . 5)))

    (paladin
     :name "Paladin" :tier 4 :weapon "Heaven Hammer"
     :advances-from white-knight
     :stat-bonus ((str . 25) (int . 10)))

    ;; ===================================================================
    ;; Magician paths
    ;; ===================================================================
    (magician
     :name "Magician" :tier 1 :weapon "Apprentice Wand"
     :advances-from beginner
     :advance-level 30
     :advance-choices (fp-wizard il-wizard cleric)
     :advance-req ((int . 65) (luk . 25))
     :stat-bonus ((int . 30)))

    ;; Path A: F/P Wizard → F/P Mage → F/P Archmage
    (fp-wizard
     :name "F/P Wizard" :tier 2 :weapon "Ember Wand"
     :advances-from magician
     :advance-level 70
     :advance-choices (fp-mage)
     :advance-req ((int . 130) (luk . 60))
     :stat-bonus ((int . 15) (luk . 5)))

    (fp-mage
     :name "F/P Mage" :tier 3 :weapon "Inferno Rod"
     :advances-from fp-wizard
     :advance-level 120
     :advance-choices (fp-archmage)
     :advance-req ((int . 200) (luk . 100))
     :stat-bonus ((int . 20)))

    (fp-archmage
     :name "F/P Archmage" :tier 4 :weapon "Apocalypse Staff"
     :advances-from fp-mage
     :stat-bonus ((int . 30)))

    ;; Path B: I/L Wizard → I/L Mage → I/L Archmage
    (il-wizard
     :name "I/L Wizard" :tier 2 :weapon "Frost Wand"
     :advances-from magician
     :advance-level 70
     :advance-choices (il-mage)
     :advance-req ((int . 130) (luk . 60))
     :stat-bonus ((int . 15) (luk . 5)))

    (il-mage
     :name "I/L Mage" :tier 3 :weapon "Blizzard Rod"
     :advances-from il-wizard
     :advance-level 120
     :advance-choices (il-archmage)
     :advance-req ((int . 200) (luk . 100))
     :stat-bonus ((int . 20)))

    (il-archmage
     :name "I/L Archmage" :tier 4 :weapon "Storm Crystal"
     :advances-from il-mage
     :stat-bonus ((int . 30)))

    ;; Path C: Cleric → Priest → Bishop
    (cleric
     :name "Cleric" :tier 2 :weapon "Holy Wand"
     :advances-from magician
     :advance-level 70
     :advance-choices (priest)
     :advance-req ((int . 130) (luk . 60))
     :stat-bonus ((int . 10) (luk . 5)))

    (priest
     :name "Priest" :tier 3 :weapon "Seraph Rod"
     :advances-from cleric
     :advance-level 120
     :advance-choices (bishop)
     :advance-req ((int . 200) (luk . 100))
     :stat-bonus ((int . 20)))

    (bishop
     :name "Bishop" :tier 4 :weapon "Heaven's Staff"
     :advances-from priest
     :stat-bonus ((int . 25) (luk . 5)))

    ;; ===================================================================
    ;; Thief paths
    ;; ===================================================================
    (thief
     :name "Thief" :tier 1 :weapon "Rusty Dagger"
     :advances-from beginner
     :advance-level 30
     :advance-choices (assassin bandit)
     :advance-req ((luk . 50) (dex . 40))
     :stat-bonus ((dex . 20) (luk . 20)))

    ;; Path A: Assassin → Hermit → Night Lord
    (assassin
     :name "Assassin" :tier 2 :weapon "Iron Claws"
     :advances-from thief
     :advance-level 70
     :advance-choices (hermit)
     :advance-req ((luk . 100) (dex . 80))
     :stat-bonus ((dex . 10) (luk . 15)))

    (hermit
     :name "Hermit" :tier 3 :weapon "Shadow Claws"
     :advances-from assassin
     :advance-level 120
     :advance-choices (night-lord)
     :advance-req ((luk . 160) (dex . 130))
     :stat-bonus ((dex . 15) (luk . 20)))

    (night-lord
     :name "Night Lord" :tier 4 :weapon "Void Talons"
     :advances-from hermit
     :stat-bonus ((dex . 20) (luk . 30)))

    ;; Path B: Bandit → Chief Bandit → Shadower
    (bandit
     :name "Bandit" :tier 2 :weapon "Boot Knife"
     :advances-from thief
     :advance-level 70
     :advance-choices (chief-bandit)
     :advance-req ((luk . 100) (dex . 80))
     :stat-bonus ((str . 10) (dex . 10) (luk . 5)))

    (chief-bandit
     :name "Chief Bandit" :tier 3 :weapon "Serpent Knife"
     :advances-from bandit
     :advance-level 120
     :advance-choices (shadower)
     :advance-req ((luk . 160) (dex . 130))
     :stat-bonus ((str . 15) (dex . 10) (luk . 10)))

    (shadower
     :name "Shadower" :tier 4 :weapon "Phantom Blade"
     :advances-from chief-bandit
     :stat-bonus ((str . 20) (dex . 15) (luk . 15)))

    ;; ===================================================================
    ;; Ranger paths
    ;; ===================================================================
    (ranger
     :name "Ranger" :tier 1 :weapon "Short Bow"
     :advances-from beginner
     :advance-level 30
     :advance-choices (bowman crossbowman)
     :advance-req ((dex . 65) (str . 25))
     :stat-bonus ((dex . 30)))

    ;; Path A: Bowman → Marksman → Bowmaster
    (bowman
     :name "Bowman" :tier 2 :weapon "War Bow"
     :advances-from ranger
     :advance-level 70
     :advance-choices (marksman)
     :advance-req ((dex . 130) (str . 60))
     :stat-bonus ((dex . 15) (str . 5)))

    (marksman
     :name "Marksman" :tier 3 :weapon "Windbow"
     :advances-from bowman
     :advance-level 120
     :advance-choices (bowmaster)
     :advance-req ((dex . 200) (str . 100))
     :stat-bonus ((dex . 20) (str . 5)))

    (bowmaster
     :name "Bowmaster" :tier 4 :weapon "Dragon Bow"
     :advances-from marksman
     :stat-bonus ((dex . 25) (str . 10)))

    ;; Path B: Crossbowman → Sniper → King Sniper
    (crossbowman
     :name "Crossbowman" :tier 2 :weapon "Crossbow"
     :advances-from ranger
     :advance-level 70
     :advance-choices (sniper)
     :advance-req ((dex . 130) (str . 60))
     :stat-bonus ((dex . 15) (str . 5)))

    (sniper
     :name "Sniper" :tier 3 :weapon "Sharpshot"
     :advances-from crossbowman
     :advance-level 120
     :advance-choices (king-sniper)
     :advance-req ((dex . 200) (str . 100))
     :stat-bonus ((dex . 20) (str . 5)))

    (king-sniper
     :name "King Sniper" :tier 4 :weapon "Siege Crossbow"
     :advances-from sniper
     :stat-bonus ((dex . 25) (str . 5)))

    ;; ===================================================================
    ;; Pirate paths
    ;; ===================================================================
    (pirate
     :name "Pirate" :tier 1 :weapon "Belaying Pin"
     :advances-from beginner
     :advance-level 30
     :advance-choices (knuckler shooter)
     :advance-req ((str . 50) (luk . 25))
     :stat-bonus ((str . 20) (dex . 10)))

    ;; Path A: Knuckler → Frontliner → Buccaneer
    (knuckler
     :name "Knuckler" :tier 2 :weapon "Iron Knuckles"
     :advances-from pirate
     :advance-level 70
     :advance-choices (frontliner)
     :advance-req ((str . 100) (luk . 80))
     :stat-bonus ((str . 15) (dex . 5)))

    (frontliner
     :name "Frontliner" :tier 3 :weapon "Battle Gauntlets"
     :advances-from knuckler
     :advance-level 120
     :advance-choices (buccaneer)
     :advance-req ((str . 160) (luk . 130))
     :stat-bonus ((str . 20) (dex . 5)))

    (buccaneer
     :name "Buccaneer" :tier 4 :weapon "Titan Fists"
     :advances-from frontliner
     :stat-bonus ((str . 30) (dex . 10)))

    ;; Path B: Shooter → Marauder → Gunslinger
    (shooter
     :name "Shooter" :tier 2 :weapon "Flintlock"
     :advances-from pirate
     :advance-level 70
     :advance-choices (marauder)
     :advance-req ((dex . 100) (luk . 80))
     :stat-bonus ((dex . 15) (luk . 5)))

    (marauder
     :name "Marauder" :tier 3 :weapon "Twin Pistols"
     :advances-from shooter
     :advance-level 120
     :advance-choices (gunslinger)
     :advance-req ((dex . 160) (luk . 130))
     :stat-bonus ((dex . 20) (luk . 5)))

    (gunslinger
     :name "Gunslinger" :tier 4 :weapon "Thunder Cannon"
     :advances-from marauder
     :stat-bonus ((dex . 25) (luk . 10))))
  "Job definitions. Each: (symbol . plist).")


;; ---------------------------------------------------------------------------
;; Accessors

(defun rpg-job-pget (job key)
  (plist-get (cdr (assq job rpg--job-tree)) key))

(defun rpg-job-name (job)
  (or (rpg-job-pget job :name) (symbol-name job)))

(defun rpg-apply-levelup (player)
  "Called by rpg-add-xp on level-up. Grants AP."
  (rpg-pmod player 'ap (lambda (a) (+ (or a 0) 5))))


;; ---------------------------------------------------------------------------
;; Advancement
;;
;; Advancing takes 24 hours of wall time after initiating with $advance.
;; The pending advance is stored in player fields:
;;   advance-pending : symbol of the target job
;;   advance-ready-at: float-time when it completes
;;
;; The idle tick in akai-bot.el calls rpg-check-pending-advance on each tick.

(defconst rpg-advance-delay-seconds (* 24 3600)
  "Seconds of wall time required between initiating and completing an advance.")

(defun rpg-advance-check (player)
  "Return error string if PLAYER cannot advance, else nil."
  (let* ((job     (rpg-pget player 'job))
         (choices (rpg-job-pget job :advance-choices))
         (adv-lvl (rpg-job-pget job :advance-level))
         (adv-req (rpg-job-pget job :advance-req))
         (lvl     (rpg-pget player 'level)))
    (cond
     ((null choices) "Max job reached — no further advancement.")
     ((< lvl adv-lvl)
      (format "Need level %d to advance (you are %d)." adv-lvl lvl))
     (t
      (when adv-req
        (let ((unmet (cl-remove-if
                      (lambda (req)
                        (>= (or (rpg-pget player (car req)) 0) (cdr req)))
                      adv-req)))
          (when unmet
            (mapconcat (lambda (req)
                         (format "Need %s %d (have %d)"
                                 (upcase (symbol-name (car req)))
                                 (cdr req)
                                 (or (rpg-pget player (car req)) 0)))
                       unmet ", "))))))))

(defun rpg-start-advance (player new-job)
  "Initiate a pending advance for PLAYER to NEW-JOB.
Returns error string or nil on success."
  (let* ((job     (rpg-pget player 'job))
         (choices (rpg-job-pget job :advance-choices))
         (err     (rpg-advance-check player)))
    (cond
     (err err)
     ((not (memq new-job choices))
      (format "Choose from: %s" (mapconcat #'rpg-job-name choices " / ")))
     ((rpg-pget player 'advance-pending)
      (let* ((pending  (rpg-pget player 'advance-pending))
             (ready-at (rpg-pget player 'advance-ready-at))
             (remaining (max 0 (round (- ready-at (float-time)))))
             (hours   (/ remaining 3600))
             (minutes (/ (% remaining 3600) 60)))
        (format "Already advancing to %s — %dh%dm remaining."
                (rpg-job-name pending) hours minutes)))
     (t
      (rpg-pset player 'advance-pending new-job)
      (rpg-pset player 'advance-ready-at (+ (float-time) rpg-advance-delay-seconds))
      (rpg-save-db)
      nil))))

(defun rpg-check-pending-advance (player)
  "If PLAYER has a pending advance that is ready, complete it.
Returns announcement string or nil."
  (let ((pending  (rpg-pget player 'advance-pending))
        (ready-at (rpg-pget player 'advance-ready-at)))
    (when (and pending ready-at (>= (float-time) ready-at))
      (rpg-pset player 'advance-pending nil)
      (rpg-pset player 'advance-ready-at nil)
      (rpg-pset player 'job pending)
      (dolist (bonus (rpg-job-pget pending :stat-bonus))
        (rpg-pmod player (car bonus)
                  (lambda (v) (+ (or v 0) (cdr bonus)))))
      (rpg-recalculate-stats player)
      (rpg-save-db)
      (format "%s has advanced to %s! Stat bonuses applied."
              (rpg-pget player 'name)
              (rpg-job-name pending)))))


(provide 'classes)
;;; classes.el ends here
