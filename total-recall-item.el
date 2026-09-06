;;; total-recall-item.el --- Item data model for memorization  -*- lexical-binding: t; -*-

;;; Commentary: Unified item data structure as a closure over a plist.

;;; Code:

(require 'json)

(defun total-recall--timestamp ()
  "Return the current time as a high-precision ISO-8601 string."
  (format-time-string "%Y-%m-%dT%H:%M:%S.%6N%z"))

(defun total-recall--generate-id ()
  "Generate a unique item ID from current time and a random suffix."
  (format "%s-%s" (time-to-seconds (current-time)) (random 9999)))

;; ---------------------------------------------------------------------------
;; Item factory
;; ---------------------------------------------------------------------------

(defun total-recall-make-item (data)
  "Return an item closure operating on plist DATA.

DATA must be a plist with at least :term and :definition.
The returned closure recognizes three commands:
- (funcall ITEM 'get KEY)    — return the value for KEY
- (funcall ITEM 'set KEY VAL) — set KEY to VAL and update :modified
- (funcall ITEM 'serialize)   — return the internal plist"
  (unless (plist-member data :term)
    (user-error "Item must have a :term"))
  (unless (plist-member data :definition)
    (user-error "Item must have a :definition"))
  (let* ((now (total-recall--timestamp))
         (id (or (plist-get data :id) (total-recall--generate-id)))
         (data (copy-sequence data)))
    ;; Fill in required fields not provided in data
    (unless (plist-member data :id)
      (setq data (plist-put data :id id)))
    (unless (plist-member data :created)
      (setq data (plist-put data :created now)))
    (unless (plist-member data :modified)
      (setq data (plist-put data :modified now)))
    (unless (plist-member data :tags)
      (setq data (plist-put data :tags nil)))
    (unless (plist-member data :depth)
      (setq data (plist-put data :depth 3)))
    (lambda (command &rest args)
      (pcase command
        ('get
         (plist-get data (car args)))
        ('set
         (setq data (plist-put data (car args) (cadr args)))
         (setq data (plist-put data :modified (total-recall--timestamp))))
        ('serialize
         data)))))

(provide 'total-recall-item)

;;; total-recall-item.el ends here