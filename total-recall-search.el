;;; total-recall-search.el --- Fuzzy search via Levenshtein distance  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Marsel Scheer

;; Author: Marsel Scheer
;; URL: https://github.com/MarselScheer/total-recall
;; Version: 0.1.0
;; Package-Requires: ((emacs "26.1"))
;; Keywords: convenience, memory, tools

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Provides an interactive command `total-recall-search` that grabs the
;; word at point and finds the closest matches in the memorization
;; database using Levenshtein (edit) distance.

;;; Code:

(require 'cl-lib)
(require 'total-recall-storage)

;; ---------------------------------------------------------------------------
;; Configuration
;; ---------------------------------------------------------------------------

(defcustom total-recall-search-count 5
  "Number of closest matches to display when running `total-recall-search'."
  :type 'integer
  :group 'total-recall)

;; ---------------------------------------------------------------------------
;; Levenshtein distance
;; ---------------------------------------------------------------------------

(defun total-recall-search--levenshtein-distance (a b)
  "Return the Levenshtein edit distance between strings A and B.

Uses a two-row dynamic programming approach with O(min(m,n)) space.
The distance is the minimum number of single-character edits (insert,
delete, substitute) needed to transform A into B."
  (let ((a-len (length a))
        (b-len (length b)))
    ;; Swap so the shorter string is the column dimension for
    ;; minimal memory use.
    (when (> a-len b-len)
      (cl-rotatef a b)
      (cl-rotatef a-len b-len))
    ;; If the shorter string is empty, distance = length of the other
    (if (zerop a-len)
        b-len
      ;; prev-row[j] = cost to transform a[0..i-1] into b[0..j-1]
      (let ((prev-row (make-vector (1+ b-len) 0))
            (curr-row (make-vector (1+ b-len) 0)))
        ;; Initialize prev-row for i=0 (empty prefix of a)
        (cl-loop for j from 0 to b-len do
                 (aset prev-row j j))
        ;; Iterate over characters of a
        (cl-loop for i from 1 to a-len do
                 (aset curr-row 0 i)
                 (cl-loop for j from 1 to b-len do
                          (let ((cost (if (= (aref a (1- i)) (aref b (1- j)))
                                         0
                                       1)))
                            (aset curr-row j
                                  (min (1+ (aref curr-row (1- j)))       ; insert
                                       (1+ (aref prev-row j))            ; delete
                                       (+ (aref prev-row (1- j)) cost)  ; substitute
                                       ))))
                 ;; Swap rows for next iteration
                 (cl-rotatef prev-row curr-row))
        ;; Result is in prev-row after final swap
        (aref prev-row b-len)))))

;; ---------------------------------------------------------------------------
;; Search logic
;; ---------------------------------------------------------------------------

(defun total-recall-search--search-fn (adapter)
  "Return a function that searches all items in ADAPTER by Levenshtein distance.

The returned function takes a WORD string and returns a list of
(ITEM-CLOSURE . DISTANCE) pairs sorted by ascending distance.
ADAPTER is a storage adapter plist (see `total-recall-storage-init')."
  (lambda (word)
    (let* ((ids (funcall (plist-get adapter :query-all)))
           (items (mapcar (lambda (id) (funcall (plist-get adapter :load-item) id)) ids))
           (results (mapcar (lambda (item)
                              (let ((term (funcall item 'get :term)))
                                (cons item (total-recall-search--levenshtein-distance
                                            word term))))
                            items)))
      (sort results (lambda (a b) (< (cdr a) (cdr b)))))))

;; ---------------------------------------------------------------------------
;; Command factory
;; ---------------------------------------------------------------------------

(defun total-recall-search-init (adapter)
  "Return an interactive search command configured with ADAPTER.

ADAPTER is a storage adapter plist (see `total-recall-storage-init').
The returned command grabs the word at point, finds the closest matches
via Levenshtein distance, and displays them in the minibuffer."
  (let ((search-fn (total-recall-search--search-fn adapter)))
    (lambda ()
      "Search memorization items by the word at point.
Results are sorted by Levenshtein distance and shown in the minibuffer."
      (interactive)
      (let* ((word (thing-at-point 'word t))
             (results (if word (funcall search-fn word)))
             (count (min total-recall-search-count (length results))))
        (cond
         ((null word)
          (message "No word found at point."))
         ((zerop (length results))
          (message "No items in database."))
         ((zerop count)
          (message "No close matches found for \"%s\"." word))
         (t
          (let* ((top (cl-subseq results 0 count))
                 (lines (mapcar (lambda (pair)
                                  (let ((item (car pair))
                                        (dist (cdr pair)))
                                    (format "\"%s\" (dist %d): %s"
                                            (funcall item 'get :term)
                                            dist
                                            (total-recall-search--truncate
                                             (funcall item 'get :definition) 80))))
                                top))
                 (msg (concat (format "Top %d matches:\n" count)
                              (string-join lines "\n"))))
            (message "%s" msg))))))))

;; ---------------------------------------------------------------------------
;; Helpers
;; ---------------------------------------------------------------------------

(defun total-recall-search--truncate (text max-length)
  "Truncate TEXT to MAX-LENGTH characters, appending \"...\" if truncated."
  (if (> (length text) max-length)
      (concat (substring text 0 max-length) "...")
    text))

;; ---------------------------------------------------------------------------
;; Database path configuration
;; ---------------------------------------------------------------------------

(defvar total-recall-search-db-path nil
  "Path to the SQLite database for search.

When nil (the default), each `total-recall-search' call uses an
in-memory database.  Set this to a file path (e.g.
\"~/.total-recall.db\") to search a persistent database.")

;;;###autoload
(defun total-recall-search ()
  "Search memorization items by the word at point.

Grabs the word at point from the current buffer, computes Levenshtein
distance to every item term in the database, and displays the top
matches in the minibuffer sorted by ascending distance."
  (interactive)
  (let* ((db-path (or total-recall-search-db-path
                      (and (boundp 'total-recall-train-db-path)
                           total-recall-train-db-path)))
         (adapter (total-recall-storage-init db-path))
         (cmd (total-recall-search-init adapter)))
    (funcall cmd)))

(provide 'total-recall-search)

;;; total-recall-search.el ends here