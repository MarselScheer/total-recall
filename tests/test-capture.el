;;; test-capture.el --- Tests for total-recall-capture  -*- lexical-binding: t; -*-

(require 'ert)
(require 'total-recall-capture)
(require 'total-recall-storage)
(require 'total-recall-tags)

;; org-capture is not always loaded in batch mode; declare the variable
;; so the registration tests can bind it locally.
(defvar org-capture-templates)

(ert-deftest test-capture-init-returns-function ()
  "total-recall-capture-init returns a function (closure)."
  (let* ((adapter (total-recall-storage-init nil))
         (fn (total-recall-capture-init adapter :register nil)))
    (should (functionp fn))))

(ert-deftest test-capture-init-commits-when-called ()
  "The returned function commits buffer content when called with a string."
  (let* ((adapter (total-recall-storage-init nil))
         (capture (total-recall-capture-init adapter :register nil))
         (id (funcall capture "term:: foo\ndefinition:: bar"))
         (loaded (funcall (plist-get adapter :load-item) id)))
    (should (stringp id))
    (should loaded)
    (should (equal (funcall loaded 'get :term) "foo"))))

;; ---------------------------------------------------------------------------
;; 2.1 Basic field parsing
;; ---------------------------------------------------------------------------

(ert-deftest test-capture-parse-basic-fields ()
  "Parse basic term:: and definition:: fields."
  (let ((input "term:: voracious\ndefinition:: extremely hungry"))
    (should (equal (total-recall-capture--parse input)
                   '(:term "voracious" :definition "extremely hungry")))))

(ert-deftest test-capture-parse-comments-ignored ()
  "Comment lines (;;) are stripped before parsing."
  (let ((input ";; this is a comment\nterm:: foo"))
    (should (equal (total-recall-capture--parse input)
                   '(:term "foo")))))

(ert-deftest test-capture-parse-continuation-lines ()
  "Indented continuation lines are joined to the previous value."
  (let ((input "definition:: a long\n definition that continues"))
    (should (equal (total-recall-capture--parse input)
                   '(:definition "a long definition that continues")))))

(ert-deftest test-capture-parse-blank-fields-omitted ()
  "Empty fields are omitted from the result plist."
  (let ((input "notes::\nterm:: foo"))
    (should (equal (total-recall-capture--parse input)
                   '(:term "foo")))))

(ert-deftest test-capture-parse-empty-buffer ()
  "Empty or comment-only buffer returns nil."
  (should (equal (total-recall-capture--parse "") nil))
  (should (equal (total-recall-capture--parse ";; just a comment") nil))
  (should (equal (total-recall-capture--parse "  ;; indented comment\n;; another") nil)))

;; ---------------------------------------------------------------------------
;; 2.2 Tag parsing
;; ---------------------------------------------------------------------------

(ert-deftest test-capture-parse-tags ()
  "Tags:: value parses space-separated :keyword tokens into symbol list."
  (let ((input "tags:: :vocabulary :german"))
    (should (equal (total-recall-capture--parse input)
                   '(:tags (:vocabulary :german))))))

;; ---------------------------------------------------------------------------
;; 2.3 Numeric parsing
;; ---------------------------------------------------------------------------

(ert-deftest test-capture-parse-depth ()
  "Depth:: value parses to an integer."
  (let ((input "depth:: 5"))
    (should (equal (total-recall-capture--parse input)
                   '(:depth 5)))))

;; ---------------------------------------------------------------------------
;; 2.4 Example parsing
;; ---------------------------------------------------------------------------

(ert-deftest test-capture-parse-example-single ()
  "Parse a single example with no props."
  (let ((input "examples::\n  - \"simple text\""))
    (should (equal (total-recall-capture--parse input)
                   '(:examples (("simple text" . ())))))))

(ert-deftest test-capture-parse-example-props ()
  "Parse an example with key-value props."
  (let ((input "examples::\n  - \"In Python\" :lang Python :version 2"))
    (should (equal (total-recall-capture--parse input)
                   '(:examples (("In Python" . (:lang "Python" :version "2"))))))))

(ert-deftest test-capture-parse-example-multi-line ()
  "Parse a multi-line example preserving line breaks."
  (let ((input "examples::\n  - \"\nclass A:\n    a: int = 20\" :lang Python"))
    (should (equal (total-recall-capture--parse input)
                   '(:examples (("\nclass A:\n    a: int = 20" . (:lang "Python"))))))))

;; ---------------------------------------------------------------------------
;; 3.1 Commit function
;; ---------------------------------------------------------------------------

(ert-deftest test-capture-commit-saves-item ()
  "Commit parses buffer, creates item, saves via adapter, returns id."
  (let* ((adapter (total-recall-storage-init nil))
         (input "term:: dependency injection\ndefinition:: passing dependencies as function arguments\ntags:: :software :design-patterns\ndepth:: 4")
         (id (total-recall-capture--commit adapter input))
         (loaded (funcall (plist-get adapter :load-item) id)))
    (should (stringp id))
    (should loaded)
    (should (equal (funcall loaded 'get :term) "dependency injection"))
    (should (equal (funcall loaded 'get :definition)
                   "passing dependencies as function arguments"))
    (should (equal (funcall loaded 'get :tags) '(:software :design-patterns)))
    (should (equal (funcall loaded 'get :depth) 4))))

;; ---------------------------------------------------------------------------
;; 3.2 Factory and registration
;; ---------------------------------------------------------------------------

(ert-deftest test-capture-init-registers-template ()
  "Init with default :register adds an org-capture template entry."
  (let* ((adapter (total-recall-storage-init nil))
         (org-capture-templates nil)
         (fn (total-recall-capture-init adapter)))
    (should (functionp fn))
    (should (= (length org-capture-templates) 1))
    (let ((entry (car org-capture-templates)))
      (should (equal (nth 0 entry) "r"))
      (should (string-match "Recall" (nth 1 entry)))
      (should (equal (nth 2 entry) 'plain)))))

(ert-deftest test-capture-init-no-register ()
  "Init with :register nil skips template registration."
  (let* ((adapter (total-recall-storage-init nil))
         (org-capture-templates nil)
         (fn (total-recall-capture-init adapter :register nil)))
    (should (functionp fn))
    (should (equal org-capture-templates nil))))

;; ---------------------------------------------------------------------------
;; 3.3 Before-finalize end-to-end flow
;; ---------------------------------------------------------------------------

(ert-deftest test-capture-before-finalize-saves-item ()
  "The :before-finalize hook in the template commits buffer content."
  (let* ((adapter (total-recall-storage-init nil))
         (org-capture-templates nil)
         (_ (total-recall-capture-init adapter))
         (entry (car org-capture-templates))
         (before-finalize (plist-get (nthcdr 5 entry) :before-finalize))
         (input "term:: dependency injection\ndefinition:: passing dependencies as function arguments\ntags:: :software :design-patterns\ndepth:: 4"))
    (should (functionp before-finalize))
    ;; Simulate a capture buffer with the input content
    (with-temp-buffer
      (insert input)
      (funcall before-finalize))
    ;; Verify item was saved — the buffer is killed, but the item
    ;; should be in the database.  We can't use :load-item since we
    ;; don't know the id, so query all and check the first item.
    (let ((ids (funcall (plist-get adapter :query-all))))
      (should (= (length ids) 1))
      (let ((loaded (funcall (plist-get adapter :load-item) (car ids))))
        (should loaded)
        (should (equal (funcall loaded 'get :term) "dependency injection"))
        (should (equal (funcall loaded 'get :definition)
                       "passing dependencies as function arguments"))
        (should (equal (funcall loaded 'get :tags) '(:software :design-patterns)))
        (should (equal (funcall loaded 'get :depth) 4))))))

;; ---------------------------------------------------------------------------
;; 4.1 End-to-end full cycle
;; ---------------------------------------------------------------------------

(ert-deftest test-capture-e2e-full-cycle ()
  "End-to-end: init storage, init capture, full capture cycle with all
fields, load item back and verify everything including tags and examples."
  (let* ((adapter (total-recall-storage-init nil))
         (capture (total-recall-capture-init adapter :register nil))
         (input "term:: dependency injection
definition:: passing dependencies as function arguments
tags:: :software :design-patterns
depth:: 4
examples::
  - \"In Python: inject via args\" :lang Python
  - \"In Java: constructor injection\" :lang Java
notes:: a fundamental concept
analogy:: like a power outlet")
         (id (funcall capture input))
         (loaded (funcall (plist-get adapter :load-item) id)))
    (should (stringp id))
    (should loaded)
    (should (equal (funcall loaded 'get :term) "dependency injection"))
    (should (equal (funcall loaded 'get :definition)
                   "passing dependencies as function arguments"))
    (should (equal (funcall loaded 'get :tags) '(:software :design-patterns)))
    (should (equal (funcall loaded 'get :depth) 4))
    (should (equal (funcall loaded 'get :examples)
                   '(("In Python: inject via args" . (:lang "Python"))
                     ("In Java: constructor injection" . (:lang "Java")))))
    (should (equal (funcall loaded 'get :notes) "a fundamental concept"))
    (should (equal (funcall loaded 'get :analogy) "like a power outlet"))))

;; ---------------------------------------------------------------------------
;; 4.3 Template correctness — :before-finalize must not kill the buffer
;; ---------------------------------------------------------------------------

(ert-deftest test-capture-before-finalize-does-not-kill-buffer ()
  "The :before-finalize function commits the buffer but does not kill it.
Killing is handled by :kill-buffer t on the template, not by the hook.
If :before-finalize kills the buffer, org-capture-finalize will crash
because it tries to restore window configuration on a dead buffer."
  (let* ((adapter (total-recall-storage-init nil))
         (org-capture-templates nil)
         (_ (total-recall-capture-init adapter))
         (entry (car org-capture-templates))
         (before-finalize (plist-get (nthcdr 5 entry) :before-finalize))
         (input "term:: test\ndefinition:: test"))
    (should (functionp before-finalize))
    (let ((buf (generate-new-buffer " *test-capture-before-finalize*")))
      (with-current-buffer buf
        (insert input)
        (funcall before-finalize))
      ;; The buffer should still be alive — :before-finalize must not kill it
      (should (buffer-live-p buf))
      (kill-buffer buf))
    ;; Verify item was still saved despite not killing the buffer
    (let ((ids (funcall (plist-get adapter :query-all))))
      (should (= (length ids) 1))
      (let ((loaded (funcall (plist-get adapter :load-item) (car ids))))
        (should (equal (funcall loaded 'get :term) "test"))))))

(ert-deftest test-capture-template-target-file-exists ()
  "After init, the template's target file exists so org-capture
doesn't prompt for a filename interactively."
  (let* ((adapter (total-recall-storage-init nil))
         (org-capture-templates nil)
         (target-file "/tmp/recall-capture.txt"))
    ;; Clean up before test
    (when (file-exists-p target-file)
      (delete-file target-file))
    (total-recall-capture-init adapter)
    ;; File should have been created
    (should (file-exists-p target-file))))

(provide 'test-capture)
;;; test-capture.el ends here