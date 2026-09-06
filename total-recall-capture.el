;;; total-recall-capture.el --- Org-capture template for memorization items  -*- lexical-binding: t; -*-

;;; Commentary: Interactive capture of memorization items via org-capture.
;;; Provides the capture template, buffer parser, and commit flow.

;;; Code:

(require 'total-recall-item)
(require 'total-recall-tags)

;; ---------------------------------------------------------------------------
;; Parser — pure function, no side effects, no dependencies
;; ---------------------------------------------------------------------------

(defun total-recall-capture--parse (input)
  "Parse capture buffer text INPUT into a plist.

Strips ;; comment lines, parses key:: value pairs, joins indented
continuation lines, and omits blank fields.  Returns nil for empty
or comment-only input."
  (when (and (stringp input) (not (string= input "")))
    (let ((lines (split-string input "\n"))
          fields current-key current-val)
      (dolist (line lines)
        (cond
         ;; Comment line — skip entirely
         ((string-match "\\`[ \t]*;;" line) nil)
         ;; Whitespace-only line — skip
         ((string-match "\\`[ \t]*\\'" line) nil)
         ;; New field header: key:: value
         ((string-match "\\`\\([a-z0-9-]+\\)::\\(.*\\)" line)
          (let ((m1 (match-string-no-properties 1 line))
                (m2 (match-string-no-properties 2 line)))
            (when current-key
              (push (list current-key (string-trim current-val)) fields))
            (setq current-key m1)
            (setq current-val m2)))
         ;; Continuation line (anything after a field header has been seen)
         (current-key
          (setq current-val (concat current-val "\n" line)))
         ;; Before any field header — skip
         (t nil)))
      (when current-key
        (push (list current-key (string-trim current-val)) fields))
      ;; Convert to plist, omitting blank fields
      (let ((pairs (nreverse fields))
            plist)
        (dolist (pair pairs)
          (let ((key (intern (concat ":" (car pair))))
                (val (cadr pair)))
            (unless (string= val "")
              (setq plist (plist-put plist key val)))))
        ;; Post-process typed fields
        (when plist
          (total-recall-capture--postprocess plist))))))

(defun total-recall-capture--postprocess (plist)
  "Apply type-specific post-processing to PLIST entries.
Returns the updated plist."
  (let ((result plist))
    ;; Normalize text fields: collapse newlines+whitespace to single space
    (dolist (key '(:term :definition :notes :analogy :source-lang :target-lang
                    :part-of-speech :prerequisites))
      (when (plist-member result key)
        (setq result (plist-put result key
                                (total-recall-capture--normalize-text
                                 (plist-get result key))))))
    ;; Tags: parse keyword symbols
    (when (plist-member result :tags)
      (setq result (plist-put result :tags
                              (total-recall-capture--parse-tags
                               (plist-get result :tags)))))
    ;; Depth: parse integer
    (when (plist-member result :depth)
      (setq result (plist-put result :depth
                              (total-recall-capture--parse-depth
                               (plist-get result :depth)))))
    ;; Examples: parse bullet format
    (when (plist-member result :examples)
      (setq result (plist-put result :examples
                              (total-recall-capture--parse-examples
                               (plist-get result :examples)))))
    result))

(defun total-recall-capture--normalize-text (str)
  "Collapse newlines and surrounding whitespace in STR to a single space."
  (replace-regexp-in-string "[ \t]*\n[ \t]*" " " str))

;; ---------------------------------------------------------------------------
;; Tag parsing (2.2)
;; ---------------------------------------------------------------------------

(defun total-recall-capture--parse-tags (value)
  "Parse tags VALUE string into a list of interned keyword symbols.
E.g. \":vocabulary :german\" → (:vocabulary :german)."
  (let ((tokens (split-string (string-trim value) "[ \t]+" t))
        (result nil))
    (dolist (tok tokens)
      (when (string-match "\\`:\\(.+\\)" tok)
        (let ((name (match-string-no-properties 1 tok)))
          (push (intern (concat ":" name)) result))))
    (nreverse result)))

;; ---------------------------------------------------------------------------
;; Numeric parsing (2.3)
;; ---------------------------------------------------------------------------

(defun total-recall-capture--parse-depth (value)
  "Parse depth VALUE string into an integer."
  (string-to-number (string-trim value)))

;; ---------------------------------------------------------------------------
;; Example parsing (2.4)
;; ---------------------------------------------------------------------------

(defun total-recall-capture--parse-examples (value)
  "Parse examples VALUE string into a list of cons cells.

Each bullet line (starting with \"- \") becomes a cons cell
\(TEXT . PROPS) where TEXT is the double-quoted string and PROPS
is a plist of alternating :key val pairs from remaining tokens."
  (let ((lines (split-string value "\n"))
        (examples nil)
        (current-text nil)
        (current-props nil)
        (in-bullet nil))
    (dolist (line lines)
      (if (string-match "\\`[ \t]*-[ \t]+\\(.*\\)" line)
          ;; New bullet line
          (progn
            ;; Save previous example if any
            (when (and current-text (not (string= current-text "")))
              (push (cons current-text current-props) examples))
            (setq current-text nil
                  current-props nil
                  in-bullet t)
            (let ((rest (match-string-no-properties 1 line)))
              ;; Case 1: fully-quoted text on one line: "text" :key val
              (if (string-match "\\`\"\\([^\"]*\\)\"\\(.*\\)" rest)
                  (progn
                    (setq current-text (match-string-no-properties 1 rest))
                    (setq current-props (total-recall-capture--parse-props
                                         (match-string-no-properties 2 rest)))
                    (setq in-bullet nil))
                ;; Case 2: opening quote, no closing quote: multi-line starts
                (if (string-match "\\`\"\\(.*\\)\\'" rest)
                    (setq current-text (match-string-no-properties 1 rest))
                  ;; Case 3: no quoted string — skip this bullet
                  (setq in-bullet nil)))))
        ;; Continuation of the current example
        (when (and in-bullet current-text)
          ;; Check if this line contains the closing quote
          (if (string-match "\"\\(.*\\)" line)
              (let ((before-quote (substring line 0 (match-beginning 0)))
                    (after-quote (match-string-no-properties 1 line)))
                (setq current-text (if (string= current-text "")
                                       before-quote
                                     (concat current-text "\n" before-quote)))
                (setq current-props (total-recall-capture--parse-props after-quote))
                (setq in-bullet nil))
            ;; Still inside the multi-line text
            (setq current-text (concat current-text "\n" line))))))
    ;; Save last example
    (when (and current-text (not (string= current-text "")))
      (push (cons current-text current-props) examples))
    (nreverse examples)))

(defun total-recall-capture--parse-props (str)
  "Parse property pairs from STR into a plist.
E.g. \":lang Python :version 2\" → (:lang \"Python\" :version \"2\")."
  (let ((tokens (split-string (string-trim str) "[ \t]+" t))
        (result nil)
        (i 0))
    (while (< i (length tokens))
      (let ((tok (nth i tokens)))
        (if (string-match "\\`:\\(.+\\)" tok)
            (let ((key (intern (concat ":" (match-string-no-properties 1 tok))))
                  (val (nth (1+ i) tokens)))
              (when val
                (setq result (plist-put result key val)))
              (setq i (+ i 2)))
          (setq i (1+ i)))))
    result))

;; ---------------------------------------------------------------------------
;; Public API
;; ---------------------------------------------------------------------------

(defun total-recall-capture--commit (adapter buffer-string)
  "Parse BUFFER-STRING, create item, apply tags, save via ADAPTER.

ADAPTER is a storage adapter plist as returned by `total-recall-storage-init'.
Returns the new item's id as a string, or nil when the buffer is empty
or comment-only."
  (let ((parsed (total-recall-capture--parse buffer-string)))
    (when parsed
      (let* ((item (total-recall-make-item parsed))
             (id (funcall item 'get :id))
             (tags (plist-get parsed :tags)))
        ;; Apply tags via the tag module (idempotent — item already has
        ;; tags from make-item, but this follows the architectural pattern)
        (when tags
          (apply #'total-recall-tag--add item tags))
        (funcall (plist-get adapter :save-item) item)
        id))))

(defun total-recall-capture-init (adapter &rest args)
  "Return a capture function configured with ADAPTER (a storage adapter plist).

ADAPTER is a storage adapter plist as returned by `total-recall-storage-init'.
Optional keyword arguments:
  :register — when non-nil (or omitted), register an org-capture template;
              when nil, skip registration.

Returns a function that, when called with a buffer string, commits it
as a new memorization item and returns the item id."
  (let ((register (if (plist-member args :register)
                      (plist-get args :register)
                    t)))
    (when register
      ;; Ensure the target file exists so org-capture doesn't
      ;; prompt for a filename interactively.
      (unless (file-exists-p "/tmp/recall-capture.txt")
        (with-temp-file "/tmp/recall-capture.txt" (insert "")))
      (add-to-list 'org-capture-templates
                   `("r" "Recall" plain
                     (file "/tmp/recall-capture.txt")
                     ,(concat
                       "term:: \n"
                       "definition:: \n"
                       ";; tags: space-separated :keyword tokens, e.g. :vocabulary :german\n"
                       "tags:: \n"
                       ";; depth: integer 1-5\n"
                       "depth:: 3\n"
                       ";; examples: bullet list with quoted text and optional :key val\n"
                       "examples:: \n"
                       "  - \n"
                       ";; notes: any additional notes\n"
                       "notes:: \n"
                       ";; analogy: comparison to something familiar\n"
                       "analogy:: \n")
                     :before-finalize
                     ,(lambda ()
                        (let ((content (buffer-substring-no-properties
                                        (point-min) (point-max))))
                          (total-recall-capture--commit adapter content)))
                     :kill-buffer t)))
    (lambda (buffer-string)
      "Run the capture flow on BUFFER-STRING."
      (total-recall-capture--commit adapter buffer-string))))

(provide 'total-recall-capture)

;;; total-recall-capture.el ends here