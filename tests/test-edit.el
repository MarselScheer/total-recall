;;; test-edit.el --- Tests for total-recall-edit  -*- lexical-binding: t; -*-

(require 'ert)
(require 'total-recall-edit)
(require 'total-recall-item)
(require 'total-recall-storage)
(require 'total-recall-sched)

;; ---------------------------------------------------------------------------
;; 1.1 — Edit mode and keybindings [SC-2026-09-19_12-33-15-01]
;; ---------------------------------------------------------------------------

(ert-deftest test-edit-mode-defined ()
  "total-recall-edit-mode is defined and derived from text-mode.
[SC-2026-09-19_12-33-15-01]"
  (should (fboundp 'total-recall-edit-mode))
  (should (boundp 'total-recall-edit-mode-map))
  (should (keymapp (default-value 'total-recall-edit-mode-map))))

(ert-deftest test-edit-mode-keybindings ()
  "total-recall-edit-mode has C-c C-c (commit) and C-c C-k (cancel).
[SC-2026-09-19_12-33-15-01]"
  (should (fboundp 'total-recall-edit-commit))
  (should (fboundp 'total-recall-edit-cancel))
  (let ((map (default-value 'total-recall-edit-mode-map)))
    (should (eq (lookup-key map (kbd "C-c C-c")) 'total-recall-edit-commit))
    (should (eq (lookup-key map (kbd "C-c C-k")) 'total-recall-edit-cancel))))

(ert-deftest test-edit-mode-is-derived ()
  "total-recall-edit-mode derives from text-mode (editable, not read-only).
[SC-2026-09-19_12-33-15-01]"
  (with-temp-buffer
    (total-recall-edit-mode)
    (should (null buffer-read-only))))

;; ---------------------------------------------------------------------------
;; 1.2 — Pre-fill function [SC-2026-09-19_12-33-15-01]
;; ---------------------------------------------------------------------------

(ert-deftest test-edit-prefill-basic ()
  "Pre-fill produces term::, definition::, tags::, depth::, examples::, notes::, analogy::.
[SC-2026-09-19_12-33-15-01]"
  (let* ((item (total-recall-make-item
                (list :term "foo" :definition "bar"
                      :tags '(:german :vocabulary)
                      :depth 5
                      :examples '(("ein Beispiel" . (:source "book")))
                      :notes "note text"
                      :analogy "analogy text")))
         (prefilled (total-recall-edit--prefill item)))
    (should (string-match-p "term:: foo" prefilled))
    (should (string-match-p "definition:: bar" prefilled))
    (should (string-match-p "tags:: :german :vocabulary" prefilled))
    (should (string-match-p "depth:: 5" prefilled))
    (should (string-match-p "examples::" prefilled))
    (should (string-match-p "notes:: note text" prefilled))
    (should (string-match-p "analogy:: analogy text" prefilled))))

(ert-deftest test-edit-prefill-roundtrips-via-parser ()
  "Pre-fill output, when parsed, produces the same field values.
[SC-2026-09-19_12-33-15-01]"
  (let* ((item (total-recall-make-item
                (list :term "foo" :definition "bar"
                      :tags '(:german :vocabulary)
                      :depth 5
                      :examples '(("ein Beispiel" . (:source "book")))
                      :notes "note text"
                      :analogy "analogy text")))
         (prefilled (total-recall-edit--prefill item))
         (parsed (total-recall-capture--parse prefilled)))
    (should (equal (plist-get parsed :term) "foo"))
    (should (equal (plist-get parsed :definition) "bar"))
    (should (equal (plist-get parsed :tags) '(:german :vocabulary)))
    (should (equal (plist-get parsed :depth) 5))
    (should (equal (plist-get parsed :notes) "note text"))
    (should (equal (plist-get parsed :analogy) "analogy text"))
    (should (equal (plist-get parsed :examples) '(("ein Beispiel" . (:source "book")))))))

(ert-deftest test-edit-prefill-nil-fields ()
  "Nil fields produce empty values in pre-fill output.
[SC-2026-09-19_12-33-15-01]"
  (let* ((item (total-recall-make-item
                (list :term "foo" :definition "bar")))
         (prefilled (total-recall-edit--prefill item)))
    (should (string-match-p "tags:: $" prefilled))
    (should (string-match-p "notes:: $" prefilled))
    (should (string-match-p "analogy:: $" prefilled))))

(ert-deftest test-edit-prefill-default-depth ()
  "Pre-fill includes depth:: 3 when item has no depth.
[SC-2026-09-19_12-33-15-01]"
  (let* ((item (total-recall-make-item
                (list :term "foo" :definition "bar")))
         (prefilled (total-recall-edit--prefill item)))
    (should (string-match-p "depth:: 3" prefilled))))

;; ---------------------------------------------------------------------------
;; 1.3 — Edit buffer opening [SC-2026-09-19_12-33-15-01]
;; ---------------------------------------------------------------------------

(ert-deftest test-edit-open-creates-buffer ()
  "total-recall-edit--open creates *total-recall-edit* with pre-filled content.
[SC-2026-09-19_12-33-15-01]"
  (let* ((adapter (total-recall-storage-init nil))
         (item (total-recall-make-item
                (list :term "foo" :definition "bar" :tags '(:german))))
         (return-buf (generate-new-buffer "*test-return*"))
         result-buf)
    (unwind-protect
        (progn
          ;; total-recall-edit--open calls switch-to-buffer, so we need
          ;; to call it in a context where that works.
          (total-recall-edit--open item adapter return-buf)
          (setq result-buf (get-buffer "*total-recall-edit*"))
          (should result-buf)
          (should (buffer-live-p result-buf))
          (with-current-buffer result-buf
            (should (eq major-mode 'total-recall-edit-mode))
            (should (string-match-p "term:: foo" (buffer-string)))
            (should (string-match-p "definition:: bar" (buffer-string)))
            (should (string-match-p "tags:: :german" (buffer-string)))))
      ;; Cleanup
      (when (buffer-live-p result-buf)
        (kill-buffer result-buf))
      (when (buffer-live-p return-buf)
        (kill-buffer return-buf)))))

(ert-deftest test-edit-open-sets-buffer-locals ()
  "total-recall-edit--open sets buffer-local variables correctly.
[SC-2026-09-19_12-33-15-01]"
  (let* ((adapter (total-recall-storage-init nil))
         (item (total-recall-make-item
                (list :term "foo" :definition "bar")))
         (return-buf (get-buffer-create "*test-return-2*"))
         result-buf)
    (unwind-protect
        (progn
          (total-recall-edit--open item adapter return-buf)
          (setq result-buf (get-buffer "*total-recall-edit*"))
          (with-current-buffer result-buf
            (should (equal total-recall-edit--original-plist
                           (funcall item 'serialize)))
            (should (eq total-recall-edit--adapter adapter))
            (should (eq total-recall-edit--return-buffer return-buf))
            (should (null total-recall-edit--after-commit-fn))))
      (when (buffer-live-p result-buf)
        (kill-buffer result-buf))
      (when (buffer-live-p return-buf)
        (kill-buffer return-buf)))))

(ert-deftest test-edit-open-cursor-at-start ()
  "total-recall-edit--open places cursor at point-min.
[SC-2026-09-19_12-33-15-01]"
  (let* ((adapter (total-recall-storage-init nil))
         (item (total-recall-make-item
                (list :term "foo" :definition "bar")))
         (return-buf (get-buffer-create "*test-return-3*"))
         result-buf)
    (unwind-protect
        (progn
          (total-recall-edit--open item adapter return-buf)
          (setq result-buf (get-buffer "*total-recall-edit*"))
          (with-current-buffer result-buf
            (should (= (point) (point-min)))))
      (when (buffer-live-p result-buf)
        (kill-buffer result-buf))
      (when (buffer-live-p return-buf)
        (kill-buffer return-buf)))))

;; ---------------------------------------------------------------------------
;; 2.1 — Commit persists changes [SC-2026-09-19_12-33-15-03]
;; ---------------------------------------------------------------------------

(ert-deftest test-edit-commit-persists-changes ()
  "Commit saves modified item data to storage and closes the edit buffer.
[SC-2026-09-19_12-33-15-03]"
  (let* ((adapter (total-recall-storage-init nil))
         (item (total-recall-make-item
                (list :term "foo" :definition "bar")))
         (id (funcall item 'get :id))
         (return-buf (get-buffer-create "*test-return-commit*")))
    (funcall (plist-get adapter :save-item) item)
    (unwind-protect
        (progn
          (total-recall-edit--open item adapter return-buf)
          (let ((edit-buf (get-buffer "*total-recall-edit*")))
            (with-current-buffer edit-buf
              (erase-buffer)
              (insert "term:: foo\ndefinition:: new-definition")
              (total-recall-edit-commit))
            ;; Edit buffer should be killed
            (should (not (buffer-live-p edit-buf)))
            ;; Item should be updated in storage
            (let ((loaded (funcall (plist-get adapter :load-item) id)))
              (should loaded)
              (should (equal (funcall loaded 'get :definition) "new-definition")))))
      (when (buffer-live-p return-buf)
        (kill-buffer return-buf)))))

;; ---------------------------------------------------------------------------
;; 2.2 — Commit preserves :id and :created [SC-2026-09-19_12-33-15-05]
;; ---------------------------------------------------------------------------

(ert-deftest test-edit-commit-preserves-id-and-created ()
  "Commit preserves :id and :created from the original item.
[SC-2026-09-19_12-33-15-05]"
  (let* ((adapter (total-recall-storage-init nil))
         (item (total-recall-make-item
                (list :term "foo" :definition "bar")))
         (original-id (funcall item 'get :id))
         (original-created (funcall item 'get :created))
         (return-buf (get-buffer-create "*test-return-id*")))
    (funcall (plist-get adapter :save-item) item)
    (unwind-protect
        (progn
          (total-recall-edit--open item adapter return-buf)
          (let ((edit-buf (get-buffer "*total-recall-edit*")))
            (with-current-buffer edit-buf
              (erase-buffer)
              (insert "term:: bar\ndefinition:: baz")
              (total-recall-edit-commit))
            (let ((loaded (funcall (plist-get adapter :load-item) original-id)))
              (should (equal (funcall loaded 'get :id) original-id))
              (should (equal (funcall loaded 'get :created) original-created)))))
      (when (buffer-live-p return-buf)
        (kill-buffer return-buf)))))

;; ---------------------------------------------------------------------------
;; 2.3 — Commit does not modify schedule [SC-2026-09-19_12-33-15-04]
;; ---------------------------------------------------------------------------

(ert-deftest test-edit-commit-does-not-modify-schedule ()
  "Editing an item does not modify its schedule records.
[SC-2026-09-19_12-33-15-04]"
  (let* ((adapter (total-recall-storage-init nil))
         (item (total-recall-make-item
                (list :term "foo" :definition "bar")))
         (id (funcall item 'get :id))
         (return-buf (get-buffer-create "*test-return-sched*")))
    (funcall (plist-get adapter :save-item) item)
    ;; Create schedule records
    (let* ((fwd-plist (list :item-id id :direction "forward"
                            :interval 10.0 :ease-factor 2.5
                            :repetitions 3 :lapses 0
                            :last-review "2000-01-01T00:00:00.000000+0000"
                            :next-review "2999-01-01T00:00:00.000000+0000"))
           (bwd-plist (list :item-id id :direction "backward"
                            :interval 5.0 :ease-factor 2.0
                            :repetitions 1 :lapses 1
                            :last-review "2000-01-01T00:00:00.000000+0000"
                            :next-review "2999-01-01T00:00:00.000000+0000")))
      (funcall (plist-get adapter :save-schedule) (total-recall-make-schedule fwd-plist))
      (funcall (plist-get adapter :save-schedule) (total-recall-make-schedule bwd-plist)))
    (unwind-protect
        (progn
          ;; Snapshot schedule serialized data before edit
          (let* ((fwd-before (funcall (plist-get adapter :load-schedule) id "forward"))
                 (bwd-before (funcall (plist-get adapter :load-schedule) id "backward"))
                 (fwd-serialized (funcall fwd-before 'serialize))
                 (bwd-serialized (funcall bwd-before 'serialize)))
            (total-recall-edit--open item adapter return-buf)
            (let ((edit-buf (get-buffer "*total-recall-edit*")))
              (with-current-buffer edit-buf
                (erase-buffer)
                (insert "term:: foo\ndefinition:: updated")
                (total-recall-edit-commit)))
            ;; Schedule should be unchanged
            (let* ((fwd-after (funcall (plist-get adapter :load-schedule) id "forward"))
                   (bwd-after (funcall (plist-get adapter :load-schedule) id "backward")))
              (should fwd-after)
              (should bwd-after)
              (should (equal (funcall fwd-after 'serialize) fwd-serialized))
              (should (equal (funcall bwd-after 'serialize) bwd-serialized)))))
      (when (buffer-live-p return-buf)
        (kill-buffer return-buf)))))

;; ---------------------------------------------------------------------------
;; 2.4 — Cancel discards changes [SC-2026-09-19_12-33-15-06]
;; ---------------------------------------------------------------------------

(ert-deftest test-edit-cancel-discards-changes ()
  "Cancel closes edit buffer; item data in storage is unchanged.
[SC-2026-09-19_12-33-15-06]"
  (let* ((adapter (total-recall-storage-init nil))
         (item (total-recall-make-item
                (list :term "foo" :definition "bar")))
         (id (funcall item 'get :id))
         (return-buf (get-buffer-create "*test-return-cancel*")))
    (funcall (plist-get adapter :save-item) item)
    (unwind-protect
        (progn
          (total-recall-edit--open item adapter return-buf)
          (let ((edit-buf (get-buffer "*total-recall-edit*")))
            (with-current-buffer edit-buf
              (erase-buffer)
              (insert "term:: foo\ndefinition:: modified")
              (total-recall-edit-cancel))
            ;; Edit buffer should be killed
            (should (not (buffer-live-p edit-buf)))
            ;; Item should be unchanged
            (let ((loaded (funcall (plist-get adapter :load-item) id)))
              (should (equal (funcall loaded 'get :definition) "bar")))))
      (when (buffer-live-p return-buf)
        (kill-buffer return-buf)))))

;; ---------------------------------------------------------------------------
;; 2.4 — Cancel returns to return buffer
;; ---------------------------------------------------------------------------

(ert-deftest test-edit-cancel-switches-to-return-buffer ()
  "Cancel switches back to the return buffer.
[SC-2026-09-19_12-33-15-06]"
  (let* ((adapter (total-recall-storage-init nil))
         (item (total-recall-make-item
                (list :term "foo" :definition "bar")))
         (return-buf (generate-new-buffer "*test-return-switch*")))
    (funcall (plist-get adapter :save-item) item)
    (unwind-protect
        (progn
          (total-recall-edit--open item adapter return-buf)
          (let ((edit-buf (get-buffer "*total-recall-edit*")))
            (with-current-buffer edit-buf
              (total-recall-edit-cancel))
            ;; Should be in return buffer now
            (should (eq (current-buffer) return-buf))))
      (when (buffer-live-p return-buf)
        (kill-buffer return-buf)))))

;; ---------------------------------------------------------------------------
;; 2.4 — Commit switches to return buffer
;; ---------------------------------------------------------------------------

(ert-deftest test-edit-commit-switches-to-return-buffer ()
  "Commit switches back to the return buffer after saving.
[SC-2026-09-19_12-33-15-03]"
  (let* ((adapter (total-recall-storage-init nil))
         (item (total-recall-make-item
                (list :term "foo" :definition "bar")))
         (return-buf (generate-new-buffer "*test-return-commit-switch*")))
    (funcall (plist-get adapter :save-item) item)
    (unwind-protect
        (progn
          (total-recall-edit--open item adapter return-buf)
          (let ((edit-buf (get-buffer "*total-recall-edit*")))
            (with-current-buffer edit-buf
              (total-recall-edit-commit))
            (should (eq (current-buffer) return-buf))))
      (when (buffer-live-p return-buf)
        (kill-buffer return-buf)))))

;; ---------------------------------------------------------------------------
;; 2.4 — Term or definition cannot be empty [SC-2026-09-19_12-33-15-07]
;; ---------------------------------------------------------------------------

(ert-deftest test-edit-commit-empty-term-signals-error ()
  "Commit signals an error when term is empty.
[SC-2026-09-19_12-33-15-07]"
  (let* ((adapter (total-recall-storage-init nil))
         (item (total-recall-make-item
                (list :term "foo" :definition "bar")))
         (return-buf (get-buffer-create "*test-return-empty*")))
    (funcall (plist-get adapter :save-item) item)
    (unwind-protect
        (progn
          (total-recall-edit--open item adapter return-buf)
          (let ((edit-buf (get-buffer "*total-recall-edit*")))
            (with-current-buffer edit-buf
              (erase-buffer)
              (insert "term:: \ndefinition:: bar")
              (should-error (total-recall-edit-commit) :type 'user-error)
              ;; Edit buffer should remain open
              (should (buffer-live-p edit-buf)))))
      (let ((edit-buf (get-buffer "*total-recall-edit*")))
        (when (buffer-live-p edit-buf)
          (kill-buffer edit-buf)))
      (when (buffer-live-p return-buf)
        (kill-buffer return-buf)))))

(ert-deftest test-edit-commit-empty-definition-signals-error ()
  "Commit signals an error when definition is empty.
[SC-2026-09-19_12-33-15-07]"
  (let* ((adapter (total-recall-storage-init nil))
         (item (total-recall-make-item
                (list :term "foo" :definition "bar")))
         (return-buf (get-buffer-create "*test-return-empty-def*")))
    (funcall (plist-get adapter :save-item) item)
    (unwind-protect
        (progn
          (total-recall-edit--open item adapter return-buf)
          (let ((edit-buf (get-buffer "*total-recall-edit*")))
            (with-current-buffer edit-buf
              (erase-buffer)
              (insert "term:: foo\ndefinition:: ")
              (should-error (total-recall-edit-commit) :type 'user-error)
              (should (buffer-live-p edit-buf)))))
      (let ((edit-buf (get-buffer "*total-recall-edit*")))
        (when (buffer-live-p edit-buf)
          (kill-buffer edit-buf)))
      (when (buffer-live-p return-buf)
        (kill-buffer return-buf)))))

;; ---------------------------------------------------------------------------
;; 2.4 — After-commit callback
;; ---------------------------------------------------------------------------

(ert-deftest test-edit-commit-calls-after-commit-fn ()
  "Commit calls the after-commit-fn (if provided) before switching back.
[SC-2026-09-19_12-33-15-03]"
  (let* ((adapter (total-recall-storage-init nil))
         (item (total-recall-make-item
                (list :term "foo" :definition "bar")))
         (return-buf (generate-new-buffer "*test-return-callback*"))
         (callback-called nil)
         (callback (lambda () (setq callback-called t))))
    (funcall (plist-get adapter :save-item) item)
    (unwind-protect
        (progn
          (total-recall-edit--open item adapter return-buf callback)
          (let ((edit-buf (get-buffer "*total-recall-edit*")))
            (with-current-buffer edit-buf
              (total-recall-edit-commit))
            (should callback-called)))
      (when (buffer-live-p return-buf)
        (kill-buffer return-buf)))))

;; ---------------------------------------------------------------------------
;; Modified timestamp is updated on commit [SC-2026-09-19_12-33-15-03]
;; ---------------------------------------------------------------------------

(ert-deftest test-edit-commit-updates-modified-timestamp ()
  "Commit updates the item's :modified timestamp.
[SC-2026-09-19_12-33-15-03]"
  (let* ((adapter (total-recall-storage-init nil))
         (item (total-recall-make-item
                (list :term "foo" :definition "bar")))
         (id (funcall item 'get :id))
         (return-buf (get-buffer-create "*test-return-ts*"))
         (original-modified (funcall item 'get :modified)))
    (funcall (plist-get adapter :save-item) item)
    (unwind-protect
        (progn
          (total-recall-edit--open item adapter return-buf)
          (let ((edit-buf (get-buffer "*total-recall-edit*")))
            (with-current-buffer edit-buf
              (erase-buffer)
              (insert "term:: foo\ndefinition:: updated")
              (total-recall-edit-commit))
            (let ((loaded (funcall (plist-get adapter :load-item) id)))
              ;; ISO 8601 timestamps are lexicographically ordered
              ;; when format is consistent
              (should (string< original-modified
                               (funcall loaded 'get :modified))))))
      (when (buffer-live-p return-buf)
        (kill-buffer return-buf)))))

(provide 'test-edit)
;;; test-edit.el ends here
