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
  :direction    \"forward\"
  :interval     0.0
  :ease-factor  2.5
  :repetitions  0
  :lapses       0
  :next-review  current timestamp

The returned closure recognizes 'get, 'set, and 'serialize commands."
  (let ((now (total-recall--timestamp))
        (data (copy-sequence data)))
    (unless (plist-member data :direction)
      (setq data (plist-put data :direction "forward")))
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

(defun total-recall-sched--sm2-grade (quality schedule &optional now-fn)
  "Grade SCHEDULE with QUALITY and return an updated schedule plist.

QUALITY is 0 (wrong) or 5 (correct).  SCHEDULE is a schedule
closure as returned by `total-recall-make-schedule'.

NOW-FN is a function of no arguments returning the current time
in `current-time' format; it defaults to `current-time'.  It is
injected so tests can control the timestamps written to
:last-review and :next-review.

SM-2 rules:
- Quality 5 increments :repetitions; interval follows 1, 6, then
  interval * ease-factor.
- Quality 0 resets :repetitions and :interval to 0, increments
  :lapses.
- Ease factor updates to EF + 0.1 (correct) or EF - 0.8 (wrong),
  floored at 1.3."
  (let* ((now (funcall (or now-fn #'current-time)))
         (item-id (funcall schedule 'get :item-id))
         (direction (funcall schedule 'get :direction))
         (reps (funcall schedule 'get :repetitions))
         (ef (funcall schedule 'get :ease-factor))
         (interval (funcall schedule 'get :interval))
         (lapses (funcall schedule 'get :lapses))
         (new-ef (max 1.3 (if (= quality 5) (+ ef 0.1) (- ef 0.8))))
         (new-reps (if (= quality 5) (1+ reps) 0))
         (new-lapses (if (= quality 5) lapses (1+ lapses)))
         (new-interval
          (cond
           ((= quality 0) 0.0)
           ((= new-reps 1) 1.0)
           ((= new-reps 2) 6.0)
           (t (* interval ef))))
         (fmt "%Y-%m-%dT%H:%M:%S.%6N%z")
         (last-review (format-time-string fmt now))
         (next-review (format-time-string fmt
                                          (time-add now (days-to-time new-interval)))))
    (list :item-id item-id
          :direction direction
          :interval new-interval
          :ease-factor new-ef
          :repetitions new-reps
          :lapses new-lapses
          :last-review last-review
          :next-review next-review)))

(provide 'total-recall-sched)

;;; total-recall-sched.el ends here
