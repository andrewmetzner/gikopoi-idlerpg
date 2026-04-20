;;; system.el --- IdleRPG core engine -*- lexical-binding: t; coding: utf-8 -*-
;;; Commentary:
;; Player DB, stats, XP/level, gold, AP, upgrades.
;; No HP/MP — combat is purely stat-based.
;; ATK = physical attack (warrior/thief/ranger/pirate)
;; MATK = magic attack (magician tree)
;;; Code:

(require 'cl-lib)
(require 'seq)


;; ---------------------------------------------------------------------------
;; Config

(defcustom rpg-db-file
  (expand-file-name "akai-bot-players.el"
                    (or (and (boundp 'gikopoi-default-directory)
                             gikopoi-default-directory)
                        default-directory))
  "Player save file." :group 'gikopoi :type 'file)


;; ---------------------------------------------------------------------------
;; XP / Level

(defun rpg-xp-to-reach-level (level)
  "Total XP needed to reach LEVEL (quadratic curve)."
  (if (<= level 1) 0
    (* (1- level) level 50)))

(defconst rpg--level-xp
  (let ((v (make-vector 201 0)))
    (dotimes (i 200) (aset v (1+ i) (rpg-xp-to-reach-level (1+ i))))
    v)
  "Vector: index N = total XP to reach level N.")

(defun rpg-level-from-xp (xp)
  "Derive level from total accumulated XP."
  (let ((lvl 1))
    (while (and (< lvl 200) (>= xp (aref rpg--level-xp (1+ lvl))))
      (cl-incf lvl))
    lvl))


;; ---------------------------------------------------------------------------
;; Player DB

(defvar rpg--players nil "In-memory list of player alists.")

(defun rpg-load-db ()
  (setq rpg--players
        (if (file-exists-p rpg-db-file)
            (with-temp-buffer
              (insert-file-contents rpg-db-file)
              (condition-case nil (read (current-buffer)) (error nil)))
          nil)))

(defun rpg-save-db ()
  (with-temp-file rpg-db-file
    (let ((print-length nil) (print-level nil))
      (pp rpg--players (current-buffer)))))

(defun rpg-get-player (name)
  (cl-find name rpg--players
           :test #'string-equal
           :key (lambda (p) (or (cdr (assq 'name p)) ""))))

(defun rpg-pget (player key)   (cdr (assq key player)))
(defun rpg-pset (player key v)
  (let ((c (assq key player)))
    (if c (setcdr c v) (nconc player (list (cons key v))))))
(defun rpg-pmod (player key fn)
  (rpg-pset player key (funcall fn (rpg-pget player key))))

(defun rpg-make-player (name)
  (list (cons 'name name) (cons 'job 'beginner)
        (cons 'level 1)   (cons 'xp 0)
        (cons 'str 4)     (cons 'dex 4)
        (cons 'int 4)     (cons 'luk 4)
        (cons 'atk 1)     (cons 'matk 0)
        (cons 'def 0)
        (cons 'gold 0)    (cons 'ap 0)
        (cons 'weapon-upgrades 0) (cons 'armor-upgrades 0)
        (cons 'mode 'battle)
        (cons 'registered (format-time-string "%Y-%m-%d"))))

(defun rpg-register-player (name)
  "Create a Beginner for NAME. Returns t or nil if already exists."
  (unless (rpg-get-player name)
    (push (rpg-make-player name) rpg--players)
    (rpg-save-db)
    t))


;; ---------------------------------------------------------------------------
;; Stats
;;
;; Physical jobs use ATK  (wbonus + primary*0.5 + secondary*0.2)
;; Magic jobs use    MATK (wbonus + INT*0.5     + LUK*0.2)
;;
;; Primary / secondary stats by class family:
;;   Warrior: STR (primary), DEX (secondary)
;;   Magician: INT (primary), LUK (secondary)
;;   Thief: LUK (primary), DEX (secondary)
;;   Ranger: DEX (primary), STR (secondary)
;;   Pirate: STR (primary), LUK (secondary)
;;
;; DEF = armor-upgrade bonus + DEX*0.2 + STR*0.1

(defun rpg--mage-job-p (job)
  "Return t if JOB is in the magician family."
  (memq job '(magician fp-wizard fp-mage fp-archmage
              il-wizard il-mage il-archmage
              cleric priest bishop)))

(defun rpg-recalculate-stats (player)
  "Recompute ATK/MATK/DEF from base stats and upgrade levels."
  (let* ((job    (rpg-pget player 'job))
         (str    (or (rpg-pget player 'str) 4))
         (dex    (or (rpg-pget player 'dex) 4))
         (int    (or (rpg-pget player 'int) 4))
         (luk    (or (rpg-pget player 'luk) 4))
         (wlvl   (or (rpg-pget player 'weapon-upgrades) 0))
         (alvl   (or (rpg-pget player 'armor-upgrades)  0))
         (wbonus (* wlvl 3))
         (abonus (* alvl 2))
         (mage-p (rpg--mage-job-p job))
         (atk
          (if mage-p 0
            (round
             (cl-case job
               ((ranger bowman crossbowman marksman sniper
                 bowmaster king-sniper shooter marauder gunslinger)
                (+ wbonus (* dex 0.5) (* str 0.2)))     ; DEX primary, STR secondary
               ((thief assassin hermit night-lord
                 bandit chief-bandit shadower)
                (+ wbonus (* luk 0.5) (* dex 0.3)))     ; LUK primary, DEX secondary
               ((pirate knuckler frontliner buccaneer)
                (+ wbonus (* str 0.5) (* luk 0.2)))     ; STR primary, LUK secondary
               (t                                        ; warrior tree + beginner
                (+ wbonus (* str 0.5) (* dex 0.2)))))))  ; STR primary, DEX secondary
         (matk
          (if mage-p
            (round (+ wbonus (* int 0.5) (* luk 0.2)))  ; INT primary, LUK secondary
            0))
         (def (round (+ abonus (* dex 0.2) (* str 0.1)))))
    (rpg-pset player 'atk  (if mage-p 0 (max 1 atk)))
    (rpg-pset player 'matk (if mage-p (max 1 matk) 0))
    (rpg-pset player 'def  (max 0 def))))


;; ---------------------------------------------------------------------------
;; XP gain + level-up
;; (rpg-apply-levelup is defined in classes.el and called here dynamically)

(defun rpg-add-xp (player amount)
  "Add AMOUNT XP to PLAYER. Returns list of announcement strings."
  (rpg-pmod player 'xp (lambda (x) (+ (or x 0) amount)))
  (let* ((new-lvl (rpg-level-from-xp (rpg-pget player 'xp)))
         (old-lvl (or (rpg-pget player 'level) 1))
         messages)
    (when (> new-lvl old-lvl)
      (rpg-pset player 'level new-lvl)
      (when (fboundp 'rpg-apply-levelup)
        (rpg-apply-levelup player))
      (push (format "%s reached level %d! [%s] +5 AP."
                    (rpg-pget player 'name)
                    new-lvl
                    (if (fboundp 'rpg-job-name)
                        (rpg-job-name (rpg-pget player 'job))
                      (symbol-name (rpg-pget player 'job))))
            messages))
    (rpg-save-db)
    (nreverse messages)))

(defun rpg-xp-to-next (player)
  "XP remaining until PLAYER's next level."
  (let ((lvl (or (rpg-pget player 'level) 1))
        (xp  (or (rpg-pget player 'xp) 0)))
    (- (aref rpg--level-xp (min 200 (1+ lvl))) xp)))


;; ---------------------------------------------------------------------------
;; Gold / AP

(defun rpg-add-gold (player amount)
  (rpg-pmod player 'gold (lambda (g) (+ (or g 0) amount))))

(defun rpg-spend-gold (player amount)
  "Deduct AMOUNT gold if available. Returns t on success, nil otherwise."
  (let ((have (or (rpg-pget player 'gold) 0)))
    (when (>= have amount)
      (rpg-pset player 'gold (- have amount)) t)))

(defun rpg-spend-ap (player stat &optional amount)
  "Spend up to AMOUNT (default 1) AP on STAT, capped by available AP.
Returns error string or nil on success."
  (let* ((ap     (or (rpg-pget player 'ap) 0))
         (amount (or amount 1)))
    (cond
     ((zerop ap)                           "No AP. Level up to gain more!")
     ((not (memq stat '(str dex int luk))) "Invalid stat. Choose: str dex int luk")
     (t
      (let ((spent (min amount ap)))
        (rpg-pmod player stat (lambda (v) (+ (or v 0) spent)))
        (rpg-pmod player 'ap  (lambda (a) (- a spent)))
        (rpg-recalculate-stats player)
        (rpg-pset player 'last-ap-spent spent)
        nil)))))


;; ---------------------------------------------------------------------------
;; Weapon / armor upgrades
;;
;; Weapon upgrades cap at +20.
;; Every 5 upgrades the stat requirements increase.
;; Requirements are checked against the class's primary and secondary stats.
;; Armor has no stat requirements, only gold.

(defun rpg-weapon-upgrade-max (player)
  "Return the weapon upgrade cap for PLAYER based on their current job tier.
Beginner(tier 0)=+5, 1st job=+10, 2nd job=+15, 3rd/4th job=+20."
  (let ((tier (if (fboundp 'rpg-job-pget)
                  (or (rpg-job-pget (rpg-pget player 'job) :tier) 0)
                0)))
    (cl-case tier
      (0  5)
      (1 10)
      (2 15)
      (t 20))))

(defun rpg--weapon-stat-pair (job)
  "Return (primary-stat . secondary-stat) for JOB's weapon upgrade requirements."
  (cond
   ((memq job '(warrior fighter spearman page crusader dragon-knight white-knight
                hero dark-knight paladin))
    '(str . dex))
   ((memq job '(magician fp-wizard fp-mage fp-archmage il-wizard il-mage il-archmage
                cleric priest bishop))
    '(int . luk))
   ((memq job '(thief assassin hermit night-lord bandit chief-bandit shadower))
    '(luk . dex))
   ((memq job '(ranger bowman crossbowman marksman sniper bowmaster king-sniper))
    '(dex . str))
   ((memq job '(pirate knuckler frontliner buccaneer shooter marauder gunslinger))
    '(str . luk))
   (t '(str . dex))))  ; beginner fallback

(defun rpg--weapon-upgrade-reqs (target-level)
  "Return (primary-req . secondary-req) for upgrading TO TARGET-LEVEL.
Tiers: +1-5 free, +6-10 need 40/20, +11-15 need 100/50, +16-20 need 200/100."
  (cond
   ((<= target-level  5) '(0   . 0))
   ((<= target-level 10) '(40  . 20))
   ((<= target-level 15) '(100 . 50))
   (t                    '(200 . 100))))

(defun rpg-upgrade-slot (player slot)
  "Upgrade SLOT ('weapon or 'armor). Costs 50*next-level gold.
Weapon upgrades check stat requirements and are capped by job tier.
Returns error string or nil on success."
  (let* ((count-key (if (eq slot 'weapon) 'weapon-upgrades 'armor-upgrades))
         (cur       (or (rpg-pget player count-key) 0))
         (next      (1+ cur))
         (cost      (* 50 next)))
    (if (eq slot 'weapon)
        ;; --- weapon: tier cap + stat reqs + gold ---
        (let ((wcap (rpg-weapon-upgrade-max player)))
          (if (>= cur wcap)
              (format "Weapon maxed at +%d for your job tier. Advance job to unlock +%d!"
                      wcap (+ wcap 5))
            (let* ((pair    (rpg--weapon-stat-pair (rpg-pget player 'job)))
                   (reqs    (rpg--weapon-upgrade-reqs next))
                   (req-pri (car reqs))
                   (req-sec (cdr reqs))
                   (p-pri   (or (rpg-pget player (car pair)) 0))
                   (p-sec   (or (rpg-pget player (cdr pair)) 0)))
              (cond
               ((< p-pri req-pri)
                (format "Need %s %d for +%d (you have %d)."
                        (upcase (symbol-name (car pair))) req-pri next p-pri))
               ((< p-sec req-sec)
                (format "Need %s %d for +%d (you have %d)."
                        (upcase (symbol-name (cdr pair))) req-sec next p-sec))
               ((not (rpg-spend-gold player cost))
                (format "Need %dg for +%d." cost next))
               (t
                (rpg-pset player count-key next)
                (rpg-recalculate-stats player)
                (rpg-save-db)
                nil)))))
      ;; --- armor: just gold ---
      (if (not (rpg-spend-gold player cost))
          (format "Need %dg. Use $toggle barter to earn gold." cost)
        (rpg-pset player count-key next)
        (rpg-recalculate-stats player)
        (rpg-save-db)
        nil))))

(defun rpg-upgrade-weapon-info (player)
  "Return a string describing the next weapon upgrade and its requirements."
  (let* ((cur  (or (rpg-pget player 'weapon-upgrades) 0))
         (next (1+ cur))
         (wcap (rpg-weapon-upgrade-max player)))
    (if (>= cur wcap)
        (format "+%d (job tier max — advance job to upgrade further)" cur)
      (let* ((pair    (rpg--weapon-stat-pair (rpg-pget player 'job)))
             (reqs    (rpg--weapon-upgrade-reqs next))
             (req-pri (car reqs))
             (req-sec (cdr reqs))
             (cost    (* 50 next))
             (req-str (if (zerop req-pri) ""
                        (format " | req %s%d %s%d"
                                (upcase (symbol-name (car pair))) req-pri
                                (upcase (symbol-name (cdr pair))) req-sec))))
        (format "+%d → +%d: %dg%s (cap +%d)" cur next cost req-str wcap)))))


;; ---------------------------------------------------------------------------
;; Stat reset

(defun rpg-job-chain-stat-bonus (job)
  "Sum all :stat-bonus values from Beginner through JOB. Returns alist."
  (let ((totals '((str . 4) (dex . 4) (int . 4) (luk . 4)))
        (j job))
    (while j
      (dolist (bonus (or (and (fboundp 'rpg-job-pget)
                              (rpg-job-pget j :stat-bonus))
                         nil))
        (let ((cell (assq (car bonus) totals)))
          (if cell (setcdr cell (+ (cdr cell) (cdr bonus)))
            (push (cons (car bonus) (cdr bonus)) totals))))
      (setq j (and (fboundp 'rpg-job-pget)
                   (rpg-job-pget j :advances-from))))
    totals))

(defun rpg-resetstats (player)
  "Refund all manually-spent AP. Costs 500g.
Returns error string or nil on success."
  (let* ((cost  500)
         (base  (rpg-job-chain-stat-bonus (rpg-pget player 'job)))
         (spent (+ (max 0 (- (or (rpg-pget player 'str) 4) (or (cdr (assq 'str base)) 4)))
                   (max 0 (- (or (rpg-pget player 'dex) 4) (or (cdr (assq 'dex base)) 4)))
                   (max 0 (- (or (rpg-pget player 'int) 4) (or (cdr (assq 'int base)) 4)))
                   (max 0 (- (or (rpg-pget player 'luk) 4) (or (cdr (assq 'luk base)) 4))))))
    (cond
     ((zerop spent) "No stats to reset.")
     ((not (rpg-spend-gold player cost))
      (format "Need %dg to reset stats." cost))
     (t
      (dolist (stat '(str dex int luk))
        (rpg-pset player stat (or (cdr (assq stat base)) 4)))
      (rpg-pmod player 'ap (lambda (a) (+ (or a 0) spent)))
      (rpg-recalculate-stats player)
      (rpg-save-db)
      nil))))


(provide 'system)
;;; system.el ends here
