;;; seed-training.el --- Seed database for manual training test  -*- lexical-binding: t; -*-

;;; Commentary:
;; Populates a SQLite database with Russian vocabulary cards and
;; schedule entries so you can manually test the interactive training
;; session (`total-recall-train-init').
;;
;; Usage:
;;   1. Open this file.
;;   2. M-x eval-buffer
;;   3. M-x seed-training
;;
;; The default database file is `total-recall-training.db' next to
;; this script.  Override via C-u M-x seed-training or by changing
;; `seed-training-db-path'.

;;; Code:

(require 'cl-lib)
(require 'total-recall)

;; ---------------------------------------------------------------------------
;; Configuration
;; ---------------------------------------------------------------------------

(defvar seed-training-db-path
  (expand-file-name "total-recall-training.db"
                    (file-name-directory
                     (or load-file-name
                         (and (boundp 'buffer-file-name) buffer-file-name)
                         default-directory)))
  "Path to the training database file used by `seed-training'.")

;; ---------------------------------------------------------------------------
;; Time helpers
;; ---------------------------------------------------------------------------

(defun seed-training--time-iso (offset-seconds)
  "Return ISO-8601 timestamp OFFSET-SECONDS from (current-time)."
  (format-time-string "%Y-%m-%dT%H:%M:%S.%6N%z"
                      (time-add (current-time) offset-seconds)))

(defun seed-training--days-ago (n)
  "Return ISO-8601 timestamp N whole days in the past."
  (seed-training--time-iso (* n -24 60 60)))

(defun seed-training--days-from-now (n)
  "Return ISO-8601 timestamp N whole days in the future."
  (seed-training--time-iso (* n 24 60 60)))

;; ---------------------------------------------------------------------------
;; Seed data
;; ---------------------------------------------------------------------------

(defun seed-training--entries ()
  "Return entries as (ITEM-PLIST . SCHEDULE-PLIST-LIST).

SCHEDULE-PLIST-LIST is a (possibly empty) list of schedule plists
to create for the item.  Each schedule plist has at least :direction
and :next-review keys.  An empty list means no schedule entry."
  (let* ((due2   (seed-training--days-ago   2))
         (due1   (seed-training--days-ago   1))
         (future (seed-training--days-from-now 3))
         (far-fu  (seed-training--days-from-now 7)))
    ;; Each element: (ITEM-PLIST . ((:direction DIR :next-review TS) ...))
    `(((:term "привет"    :definition "hello; hi"           :tags (:basic))
       . ((:direction "forward"  :next-review ,due2)))
      ((:term "спасибо"   :definition "thank you"            :tags (:basic))
       . ((:direction "forward"  :next-review ,due2)))
      ((:term "да"        :definition "yes"                  :tags (:basic))
       . ((:direction "forward"  :next-review ,due1)))
      ((:term "нет"       :definition "no"                   :tags (:basic))
       . ((:direction "forward"  :next-review ,due1)))
      ;; --- nouns tag — test tag filtering ---
      ((:term "книга"     :definition "book"                 :tags (:nouns))
       . ((:direction "forward"  :next-review ,due2)))
      ((:term "вода"      :definition "water"                :tags (:nouns))
       . ((:direction "forward"  :next-review ,due2)))
      ;; --- both directions due — tests "both" mode ---
      ((:term "хорошо"    :definition "good; well"           :tags (:basic))
       . ((:direction "forward"  :next-review ,due1)
          (:direction "backward" :next-review ,due1)))
      ;; --- not-yet-due items ---
      ((:term "большой"   :definition "big; large"           :tags (:basic))
       . ((:direction "forward"  :next-review ,future)))
      ((:term "плохо"     :definition "bad; poorly"          :tags (:basic))
       . ((:direction "forward"  :next-review ,far-fu)))
      ;; --- new items with no schedule ---
      ((:term "маленький" :definition "small; little"        :tags (:basic))
       . ())
      ((:term "красивый"  :definition "beautiful"            :tags (:basic))
       . ()))))

;; ---------------------------------------------------------------------------
;; Main
;; ---------------------------------------------------------------------------

;;;###autoload
(defun seed-training (&optional db-path)
  "Seed the training database with Russian vocabulary cards.

Optional DB-PATH overrides `seed-training-db-path'.
When called interactively with \\[universal-argument], prompt for a path."
  (interactive
   (list (if current-prefix-arg
             (read-file-name "Database path: " nil seed-training-db-path nil nil)
           seed-training-db-path)))
  (let ((path (or db-path seed-training-db-path)))
    (when (file-exists-p path)
      (delete-file path)
      (message "Removed existing database: %s" path))
    (let* ((adapter (total-recall-storage-init path))
           (entries (seed-training--entries))
           (item-count 0)
           (schedule-count 0)
           (due-forward 0)
           (due-backward 0)
           (new-items 0))
      (dolist (entry entries)
        (let* ((item-plist (car entry))
               (schedule-plists (cdr entry))
               (item (total-recall-make-item item-plist))
               (id (funcall item 'get :id)))
          (funcall (plist-get adapter :save-item) item)
          (cl-incf item-count)
          (if (null schedule-plists)
              (cl-incf new-items)
            (dolist (sched-plist schedule-plists)
              (let* ((sched-data (copy-sequence sched-plist))
                     (sched-data (plist-put sched-data :item-id id)))
                (funcall (plist-get adapter :save-schedule)
                         (total-recall-make-schedule sched-data))
                (cl-incf schedule-count)
                (pcase (plist-get sched-plist :direction)
                  ("forward"  (cl-incf due-forward))
                  ("backward" (cl-incf due-backward))))))))
      (message (concat "✔ Seed complete: %d items, %d schedule entries"
                        " (%d forward, %d backward, %d new w/o schedule)"
                        " → %s")
               item-count schedule-count due-forward due-backward new-items
               path))))

(provide 'seed-training)

;;; seed-training.el ends here