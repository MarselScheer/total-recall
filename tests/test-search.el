;;; test-search.el --- Tests for total-recall-search  -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'total-recall-search)
(require 'total-recall-storage)

;; Declare this special so cl-letf can bind it in tests
;; (normally defined in total-recall-train.el)
(defvar total-recall-train-db-path)

;; ---------------------------------------------------------------------------
;; 1 — Levenshtein distance
;; ---------------------------------------------------------------------------

(ert-deftest test-levenshtein-equal-strings ()
  "Distance is 0 for two identical strings."
  (should (= (total-recall-search--levenshtein-distance "abc" "abc") 0))
  (should (= (total-recall-search--levenshtein-distance "" "") 0))
  (should (= (total-recall-search--levenshtein-distance "x" "x") 0)))

(ert-deftest test-levenshtein-one-empty-string ()
  "Distance with one empty string equals the length of the other."
  (should (= (total-recall-search--levenshtein-distance "" "abc") 3))
  (should (= (total-recall-search--levenshtein-distance "abc" "") 3))
  (should (= (total-recall-search--levenshtein-distance "" "x") 1))
  (should (= (total-recall-search--levenshtein-distance "x" "") 1)))

(ert-deftest test-levenshtein-single-insertion ()
  "Distance of 1 for a single insertion."
  (should (= (total-recall-search--levenshtein-distance "abc" "abxc") 1))
  (should (= (total-recall-search--levenshtein-distance "abc" "xabc") 1))
  (should (= (total-recall-search--levenshtein-distance "abc" "abcx") 1)))

(ert-deftest test-levenshtein-single-deletion ()
  "Distance of 1 for a single deletion."
  (should (= (total-recall-search--levenshtein-distance "abxc" "abc") 1))
  (should (= (total-recall-search--levenshtein-distance "xabc" "abc") 1))
  (should (= (total-recall-search--levenshtein-distance "abcx" "abc") 1)))

(ert-deftest test-levenshtein-single-substitution ()
  "Distance of 1 for a single character substitution."
  (should (= (total-recall-search--levenshtein-distance "abc" "axc") 1))
  (should (= (total-recall-search--levenshtein-distance "abc" "xbc") 1))
  (should (= (total-recall-search--levenshtein-distance "abc" "abx") 1)))

(ert-deftest test-levenshtein-general-multi-edit ()
  "Distance for general multi-edit transformations."
  (should (= (total-recall-search--levenshtein-distance "kitten" "sitting") 3))
  (should (= (total-recall-search--levenshtein-distance "saturday" "sunday") 3)))

(ert-deftest test-levenshtein-asymmetric ()
  "Distance for asymmetric string pairs (different lengths)."
  (should (= (total-recall-search--levenshtein-distance "abc" "abcdef") 3))
  (should (= (total-recall-search--levenshtein-distance "abcdef" "abc") 3)))

;; ---------------------------------------------------------------------------
;; 2 — Search command
;; ---------------------------------------------------------------------------

(defun test-search--make-item (adapter term)
  "Save an item with TERM to ADAPTER and return the item closure."
  (let ((item (total-recall-make-item `(:term ,term :definition ,(concat "Definition of " term)))))
    (funcall (plist-get adapter :save-item) item)
    item))

(ert-deftest test-search-exact-match-first ()
  "Exact match appears first in results with distance 0."
  (let* ((adapter (total-recall-storage-init nil))
         (cmd (total-recall-search--search-fn adapter))
         (item-a (test-search--make-item adapter "voracious"))
         (item-b (test-search--make-item adapter "voraciously"))
         (item-c (test-search--make-item adapter "veracious"))
         (results (funcall cmd "voracious")))
    (should (= (length results) 3))
    (should (= (cdar results) 0))
    (should (equal (funcall (caar results) 'get :term) "voracious"))))

(ert-deftest test-search-sorted-by-distance ()
  "Results are sorted by ascending Levenshtein distance."
  (let* ((adapter (total-recall-storage-init nil))
         (cmd (total-recall-search--search-fn adapter))
         (item-close (test-search--make-item adapter "храбрость"))  ; dist to "храбрый"
         (item-mid   (test-search--make-item adapter "храбрец"))    ; dist to "храбрый"
         (item-far   (test-search--make-item adapter "слабость"))   ; dist to "храбрый"
         (results (funcall cmd "храбрый")))
    (should (= (length results) 3))
    ;; храбрость should be closest, храбрец middle, слабость farthest
    (should (<= (cdar results) (cdadr results) (cdaddr results)))))

(ert-deftest test-search-no-word-at-point ()
  "No word at point shows an appropriate message."
  (let* ((adapter (total-recall-storage-init nil))
         (cmd (total-recall-search-init adapter))
         messages)
    (cl-letf (((symbol-function 'thing-at-point) (lambda (&rest _) nil))
              ((symbol-function 'message) (lambda (fmt &rest args)
                                            (push (apply #'format fmt args) messages))))
      (funcall cmd))
    (should (equal (car messages) "No word found at point."))))

(ert-deftest test-search-empty-database ()
  "Empty database shows an appropriate message."
  (let* ((adapter (total-recall-storage-init nil))
         (cmd (total-recall-search-init adapter))
         messages)
    (cl-letf (((symbol-function 'thing-at-point) (lambda (&rest _) "test"))
              ((symbol-function 'message) (lambda (fmt &rest args)
                                            (push (apply #'format fmt args) messages))))
      (funcall cmd))
    (should (equal (car messages) "No items in database."))))

(ert-deftest test-search-count-limits-results ()
  "total-recall-search-count limits the number of results."
  (let* ((adapter (total-recall-storage-init nil))
         (cmd (total-recall-search-init adapter))
         (items '("apple" "apricot" "avocado" "banana" "berry" "cherry" "date"))
         messages)
    (dolist (term items)
      (test-search--make-item adapter term))
    (cl-letf (((symbol-function 'thing-at-point) (lambda (&rest _) "a"))
              ((symbol-function 'message) (lambda (fmt &rest args)
                                            (push (apply #'format fmt args) messages)))
              (total-recall-search-count 3))
      (funcall cmd))
    (should (string-prefix-p "Top 3 matches:" (car messages)))))

;; ---------------------------------------------------------------------------
;; 3 — Database path fallback
;; ---------------------------------------------------------------------------

(ert-deftest test-search-uses-search-db-path ()
  "total-recall-search passes `total-recall-search-db-path' to storage-init."
  (let* ((adapter (total-recall-storage-init nil))
         (captured-path 'not-called)
         messages)
    (cl-letf (((symbol-function 'total-recall-storage-init)
               (lambda (path) (setq captured-path path) adapter))
              ((symbol-function 'thing-at-point) (lambda (&rest _) "test"))
              ((symbol-function 'message) (lambda (fmt &rest args)
                                            (push (apply #'format fmt args) messages)))
              (total-recall-search-db-path "/some/search.db")
              (total-recall-train-db-path "/some/train.db"))
      (total-recall-search))
    (should (equal captured-path "/some/search.db"))))

(ert-deftest test-search-falls-back-to-train-db-path ()
  "When `total-recall-search-db-path' is nil, falls back to `total-recall-train-db-path'."
  (let* ((adapter (total-recall-storage-init nil))
         (captured-path 'not-called)
         messages)
    (cl-letf (((symbol-function 'total-recall-storage-init)
               (lambda (path) (setq captured-path path) adapter))
              ((symbol-function 'thing-at-point) (lambda (&rest _) "test"))
              ((symbol-function 'message) (lambda (fmt &rest args)
                                            (push (apply #'format fmt args) messages)))
              (total-recall-search-db-path nil)
              (total-recall-train-db-path "/some/train.db"))
      (total-recall-search))
    (should (equal captured-path "/some/train.db"))))

(provide 'test-search)
;;; test-search.el ends here