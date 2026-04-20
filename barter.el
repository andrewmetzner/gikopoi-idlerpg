;;; barter.el --- IdleRPG barter/trade system -*- lexical-binding: t; coding: utf-8 -*-
;;; Commentary:
;; Players in barter mode can list items for gold. Others can browse and buy.
;;; Code:

(require 'system)


;; ---------------------------------------------------------------------------
;; Shop listings
;; Stored on player record as: barter-shop = ((item-id . gold-price) ...)

(defun rpg-shop-listings (player)
  (or (rpg-pget player 'barter-shop) nil))

(defun rpg-shop-list-item (player item-id price)
  "Add ITEM-ID to PLAYER's shop for PRICE gold.
Returns error string or nil on success."
  (cond
   ((not (rpg-has-item player item-id))
    (format "You don't have %s." (rpg-item-name item-id)))
   ((<= price 0) "Price must be at least 1 gold.")
   (t
    (rpg-remove-item player item-id)
    (let* ((shop (rpg-shop-listings player))
           (cell (assq item-id shop)))
      (if cell (setcdr cell price)
        (rpg-pset player 'barter-shop
                  (cons (cons item-id price) (or shop nil)))))
    (rpg-save-db)
    nil)))

(defun rpg-shop-unlist-item (player item-id)
  "Remove ITEM-ID from PLAYER's shop, returning it to inventory."
  (let* ((shop (rpg-shop-listings player))
         (cell (assq item-id shop)))
    (when cell
      (rpg-add-item player item-id)
      (rpg-pset player 'barter-shop (assq-delete-all item-id shop))
      (rpg-save-db)
      t)))

(defun rpg-shop-clear (player)
  "Return all listed items to PLAYER's inventory and clear shop."
  (dolist (listing (rpg-shop-listings player))
    (rpg-add-item player (car listing)))
  (rpg-pset player 'barter-shop nil)
  (rpg-save-db))


;; ---------------------------------------------------------------------------
;; Buying

(defun rpg-barter-buy (buyer-name seller-name item-id)
  "BUYER-NAME buys ITEM-ID from SELLER-NAME's shop.
Returns list of result strings."
  (let ((buyer  (rpg-get-player buyer-name))
        (seller (rpg-get-player seller-name)))
    (cond
     ((null buyer)
      (list (format "%s: You are not registered." buyer-name)))
     ((null seller)
      (list (format "No player named '%s'." seller-name)))
     ((string-equal buyer-name seller-name)
      (list "You cannot buy from yourself."))
     (t
      (let* ((shop    (rpg-shop-listings seller))
             (listing (assq item-id shop)))
        (cond
         ((null listing)
          (list (format "%s is not selling %s."
                        seller-name (rpg-item-name item-id))))
         (t
          (let ((price (cdr listing)))
            (if (not (rpg-spend-gold buyer price))
                (list (format "%s: Not enough gold — need %dg, have %dg."
                              buyer-name price
                              (or (rpg-pget buyer 'gold) 0)))
              (rpg-add-gold seller price)
              (rpg-add-item buyer item-id)
              (rpg-pset seller 'barter-shop
                        (assq-delete-all item-id shop))
              (rpg-save-db)
              (list (format "%s bought %s from %s for %dg!"
                            buyer-name (rpg-item-name item-id)
                            seller-name price)))))))))))


;; ---------------------------------------------------------------------------
;; Market overview

(defun rpg-market-snapshot (room-user-names)
  "Return list of listing strings for all open shops in ROOM-USER-NAMES."
  (let (out)
    (dolist (name room-user-names)
      (when-let ((p (rpg-get-player name)))
        (when (eq (rpg-pget p 'mode) 'barter)
          (dolist (listing (rpg-shop-listings p))
            (push (format "%s:%s=%dg"
                          name
                          (rpg-item-name (car listing))
                          (cdr listing))
                  out)))))
    (nreverse out)))


(provide 'barter)
;;; barter.el ends here
