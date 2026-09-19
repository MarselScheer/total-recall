;;; total-recall-edit.el --- Edit memorization items interactively  -*- lexical-binding: t; -*-

;;; Commentary: Interactive editing of memorization item content via a
;;; dedicated edit buffer.  Reuses the capture parser for format
;;; consistency between capture and edit flows.

;;; Code:

(require 'total-recall-capture)
(require 'total-recall-item)

;; ---------------------------------------------------------------------------
;; Buffer-local state
;; ---------------------------------------------------------------------------

(defvar-local total-recall-edit--original-plist nil
  "Buffer-local: the original item plist before editing.")
(defvar-local total-recall-edit--adapter nil
  "Buffer-local: the storage adapter plist.")
(defvar-local total-recall-edit--return-buffer nil
  "Buffer-local: the buffer to return to after commit or cancel.")
(defvar-local total-recall-edit--after-commit-fn nil
  "Buffer-local: function to call after successful commit (no args).")

;; ---------------------------------------------------------------------------
;; Pre-fill
;; ---------------------------------------------------------------------------

(defun total-recall-edit--prefill (item)
  "Return a `key:: value' string for ITEM's editable fields.

ITEM is an item closure as returned by `total-recall-make-item'.
Editable fields: term, definition, tags, depth, examples, notes, analogy.
The output format matches the capture template format so that
`total-recall-capture--parse' can round-trip the content."
  (let* ((term (or (funcall item 'get :term) ""))
         (definition (or (funcall item 'get :definition) ""))
         (tags (funcall item 'get :tags))
         (depth (funcall item 'get :depth))
         (examples (funcall item 'get :examples))
         (notes (or (funcall item 'get :notes) ""))
         (analogy (or (funcall item 'get :analogy) ""))
         lines)
    (push (format "term:: %s" term) lines)
    (push (format "definition:: %s" definition) lines)
    (push (format "tags:: %s"
                  (if tags
                      (mapconcat #'symbol-name tags " ")
                    ""))
          lines)
    (push (format "depth:: %d" (or depth 3)) lines)
    ;; Examples: bullet format
    (if examples
        (progn
          (push "examples:: " lines)
          (dolist (ex examples)
            (let ((text (car ex))
                  (props (cdr ex)))
              (if props
                  (let ((prop-pairs nil))
                    (cl-loop for (k v) on props by #'cddr
                             do (push (format ":%s %s"
                                              (substring (symbol-name k) 1)
                                              v)
                                      prop-pairs))
                    (push (format "  - \"%s\" %s"
                                  text
                                  (mapconcat #'identity (nreverse prop-pairs) " "))
                          lines))
                (push (format "  - \"%s\"" text) lines)))))
      (push "examples:: " lines))
    (push (format "notes:: %s" notes) lines)
    (push (format "analogy:: %s" analogy) lines)
    (mapconcat #'identity (nreverse lines) "\n")))

;; ---------------------------------------------------------------------------
;; Edit buffer opening
;; ---------------------------------------------------------------------------

(defun total-recall-edit--open (item adapter return-buffer &optional after-commit-fn)
  "Open an edit buffer for ITEM.

ITEM is an item closure.
ADAPTER is a storage adapter plist (see `total-recall-storage-init').
RETURN-BUFFER is the buffer to switch to after commit or cancel.
AFTER-COMMIT-FN is an optional function of no arguments called
after a successful commit before returning to RETURN-BUFFER."
  (let ((buf (generate-new-buffer "*total-recall-edit*"))
        (prefilled (total-recall-edit--prefill item)))
    (switch-to-buffer buf)
    (total-recall-edit-mode)
    (setq-local total-recall-edit--original-plist (funcall item 'serialize))
    (setq-local total-recall-edit--adapter adapter)
    (setq-local total-recall-edit--return-buffer return-buffer)
    (setq-local total-recall-edit--after-commit-fn after-commit-fn)
    (insert prefilled)
    (goto-char (point-min))))

;; ---------------------------------------------------------------------------
;; Commit
;; ---------------------------------------------------------------------------

(defun total-recall-edit-commit ()
  "Commit edits from the current edit buffer.

Parses the buffer with `total-recall-capture--parse', validates that
term and definition are non-nil (signals `user-error' otherwise),
merges parsed fields over the original item plist (preserving
`:id' and `:created'), creates a new item via `total-recall-make-item',
saves via the adapter, calls the after-commit-fn (if any), kills the
edit buffer, and switches back to the return buffer."
  (interactive)
  (let* ((buffer-string (save-restriction
                          (widen)
                          (buffer-string)))
         (parsed (total-recall-capture--parse buffer-string)))
    (unless parsed
      (user-error "No content to commit"))
    (unless (plist-get parsed :term)
      (user-error "Item must have a :term"))
    (unless (plist-get parsed :definition)
      (user-error "Item must have a :definition"))
    (let* ((original total-recall-edit--original-plist)
           ;; Merge: parsed fields replace original values.
           ;; Explicitly preserve :id and :created from the original.
           (merged (plist-put (copy-sequence parsed)
                              :id (plist-get original :id)))
           (merged (plist-put merged
                              :created (plist-get original :created)))
           (item (total-recall-make-item merged))
           (adapter total-recall-edit--adapter)
           (return-buf total-recall-edit--return-buffer)
           (after-fn total-recall-edit--after-commit-fn))
      (funcall (plist-get adapter :save-item) item)
      (let ((kill-buf (current-buffer)))
        (when (and after-fn (functionp after-fn))
          (funcall after-fn))
        (kill-buffer kill-buf)
        (when (buffer-live-p return-buf)
          (switch-to-buffer return-buf))))))

;; ---------------------------------------------------------------------------
;; Cancel
;; ---------------------------------------------------------------------------

(defun total-recall-edit-cancel ()
  "Cancel edits: kill the edit buffer and return to the return buffer.
Item data in storage is unchanged."
  (interactive)
  (let ((return-buf total-recall-edit--return-buffer))
    (kill-buffer (current-buffer))
    (when (buffer-live-p return-buf)
      (switch-to-buffer return-buf))))

;; ---------------------------------------------------------------------------
;; Major mode
;; ---------------------------------------------------------------------------

(defvar total-recall-edit-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-c") 'total-recall-edit-commit)
    (define-key map (kbd "C-c C-k") 'total-recall-edit-cancel)
    map)
  "Keymap for `total-recall-edit-mode'.")

(define-derived-mode total-recall-edit-mode text-mode
  "TotalRecall-Edit"
  "Major mode for editing memorization item content.

Keybindings:
  C-c C-c  - commit edits (save and return)
  C-c C-k  - cancel edits (discard and return)
\\{total-recall-edit-mode-map}"
  (setq buffer-read-only nil))

(provide 'total-recall-edit)

;;; total-recall-edit.el ends here