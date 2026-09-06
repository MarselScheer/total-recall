;;; total-recall-tags.el --- Tag operations for memorization items  -*- lexical-binding: t; -*-

;;; Commentary: Tag operations for adding, removing, and listing tags on
;;; memorization items.  Tags are stored as a list of symbols in the
;;; item's `:tags' field.

;;; Code:

(require 'cl-lib)

;; ---------------------------------------------------------------------------
;; Adding tags
;; ---------------------------------------------------------------------------

(defun total-recall-tag--add (item tag &rest tags)
  "Add TAG and TAGS (symbols) to ITEM's `:tags' list.

Duplicate tags are silently ignored (idempotent).  Returns ITEM."
  (let* ((current (funcall item 'get :tags))
         (all-tags (cons tag tags))
         (new-tags (cl-loop for tg in all-tags
                            unless (memq tg current)
                            collect tg)))
    (when new-tags
      (funcall item 'set :tags (append current new-tags)))
    item))

;; ---------------------------------------------------------------------------
;; Removing tags
;; ---------------------------------------------------------------------------

(defun total-recall-tag--remove (item tag &rest tags)
  "Remove TAG and TAGS (symbols) from ITEM's `:tags' list.

Non-existent tags are silently ignored.  Returns ITEM."
  (let* ((remove-set (cons tag tags))
         (current (funcall item 'get :tags))
         (new-tags (cl-loop for tg in current
                            unless (memq tg remove-set)
                            collect tg)))
    (funcall item 'set :tags new-tags)
    item))

;; ---------------------------------------------------------------------------
;; Listing all tags
;; ---------------------------------------------------------------------------

(defun total-recall-tag--list-all (adapter)
  "Return every distinct tag symbol across all items using ADAPTER.

ADAPTER is a storage adapter plist (see `total-recall-storage-init').
Returns nil when no items have tags."
  (funcall (plist-get adapter :list-all-tags)))

(provide 'total-recall-tags)

;;; total-recall-tags.el ends here