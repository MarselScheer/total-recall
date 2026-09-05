;;; total-recall-sched.el --- Scheduling record data model  -*- lexical-binding: t; -*-

;;; Commentary: Scheduling record as a closure over a plist, tracking
;;; SM-2 state (interval, ease factor, repetitions, next review, lapses).

;;; Code:

(require 'total-recall-item)

;; ---------------------------------------------------------------------------
;; Schedule factory
;; ---------------------------------------------------------------------------

(defun total-recall-make-schedule (data)
  "Return a schedule closure operating on plist DATA.

DATA must provide at least :item-id.
Default values:
  :interval     0.0
  :ease-factor  2.5
  :repetitions  0
  :lapses       0
  :next-review  current timestamp

The returned closure recognizes 'get, 'set, and 'serialize commands."
  (let ((now (total-recall--timestamp))
        (data (copy-sequence data)))
    (unless (plist-member data :interval)
      (setq data (plist-put data :interval 0.0)))
    (unless (plist-member data :ease-factor)
      (setq data (plist-put data :ease-factor 2.5)))
    (unless (plist-member data :repetitions)
      (setq data (plist-put data :repetitions 0)))
    (unless (plist-member data :lapses)
      (setq data (plist-put data :lapses 0)))
    (unless (plist-member data :next-review)
      (setq data (plist-put data :next-review now)))
    (lambda (command &rest args)
      (pcase command
        ('get
         (plist-get data (car args)))
        ('set
         (setq data (plist-put data (car args) (cadr args))))
        ('serialize
         data)))))

(provide 'total-recall-sched)

;;; total-recall-sched.el ends here