;;; total-recall-train.el --- Interactive training session  -*- lexical-binding: t; -*-

;;; Commentary: Interactive training buffer for reviewing memorization
;;; items via spaced repetition.  Provides queue building, card display,
;;; and binary grading (correct/wrong).

;;; Code:

(require 'cl-lib)
(require 'total-recall-item)
(require 'total-recall-sched)
(require 'total-recall-storage)

;; ---------------------------------------------------------------------------
;; Configuration
;; ---------------------------------------------------------------------------

(defvar total-recall-train-db-path nil
  "Path to the SQLite database for training sessions.

When nil (the default), each interactive `total-recall-train' session
uses an in-memory database — useful for ephemeral testing but not for
persistent review.  Set this to a file path (e.g. \"~/.total-recall.db\")
to make data persist across sessions.")

;; ---------------------------------------------------------------------------
;; Shuffle
;; ---------------------------------------------------------------------------

(defun total-recall-train--shuffle (list &optional random-fn)
  "Return a shuffled copy of LIST via Fisher-Yates.

RANDOM-FN (optional) is a function of one integer N returning a
nonnegative integer < N; it defaults to `random'."
  (let ((random-fn (or random-fn #'random))
        (vec (vconcat list))
        (n (length list)))
    (cl-loop for i downfrom (1- n) downto 1
             do (let ((j (funcall random-fn (1+ i))))
                  (cl-rotatef (aref vec i) (aref vec j))))
    (append vec nil)))

;; ---------------------------------------------------------------------------
;; Queue builder
;; ---------------------------------------------------------------------------

(defun total-recall-train--build-queue (adapter direction &optional tag shuffle-fn)
  "Build a training queue of (ITEM-CLOSURE . DIRECTION) pairs.

ADAPTER is a storage adapter plist (see `total-recall-storage-init').
DIRECTION is a string: \"forward\", \"backward\", or \"both\".
TAG (optional, symbol) filters to items carrying that tag — nil
means no filtering.
SHUFFLE-FN (optional) is a function that takes a list and returns
a shuffled copy; it defaults to `total-recall-train--shuffle'.

Steps:
(a) query due items for each selected direction,
(b) apply tag filter when provided,
(c) deduplicate by (item-id . direction) pairs,
(d) shuffle the queue,
(e) return list of (item . direction) pairs."
  (let* ((directions (pcase direction
                       ("both" '("forward" "backward"))
                       (_ (list direction))))
         ;; (a) Query due items for each direction
         (pairs (cl-loop for dir in directions
                         append (mapcar (lambda (item) (cons item dir))
                                        (funcall (plist-get adapter :query-due) dir))))
         ;; (b) Apply tag filter when provided
         (tagged (if tag
                     (cl-remove-if-not
                      (lambda (pair)
                        (memq tag (funcall (car pair) 'get :tags)))
                      pairs)
                   pairs))
         ;; (c) Deduplicate by (item-id . direction)
         (unique (cl-remove-duplicates
                  tagged
                  :test (lambda (a b)
                          (and (string= (funcall (car a) 'get :id)
                                        (funcall (car b) 'get :id))
                               (string= (cdr a) (cdr b)))))))
    ;; (d) Shuffle and return
    (funcall (or shuffle-fn #'total-recall-train--shuffle) unique)))

;; ---------------------------------------------------------------------------
;; Direction prompt helper
;; ---------------------------------------------------------------------------

(defun total-recall-train--direction-from-char (char)
  "Map CHAR to a direction string.
?f → \"forward\", ?b → \"backward\", ?t → \"both\".
Returns nil for unrecognized chars."
  (pcase char
    (?f "forward")
    (?b "backward")
    (?t "both")
    (_ nil)))

(defun total-recall-train--prompt-direction ()
  "Prompt the user for a training direction using `read-char-choice'.
Returns \"forward\", \"backward\", or \"both\"."
  (let ((char (read-char-choice
               "Direction: (f)orward, (b)ackward, bo(t)h? "
               '(?f ?b ?t))))
    (total-recall-train--direction-from-char char)))

;; ---------------------------------------------------------------------------
;; Tag prompt helper
;; ---------------------------------------------------------------------------

(defun total-recall-train--tag-from-choice (choice)
  "Convert a COMPLETING-READ result string to a tag symbol or nil.

Empty or whitespace-only CHOICE returns nil (all items).
Valid symbol names are interned as regular symbols.
E.g. \"german\" → german (same representation as `:list-all-tags')."
  (let ((trimmed (string-trim choice)))
    (unless (string= trimmed "")
      (intern trimmed))))

(defun total-recall-train--choose-tag (adapter)
  "Prompt for an optional tag using `completing-read'.
ADAPTER provides :list-all-tags.  Returns a tag symbol, or nil
when the user skips (all items)."
  (let* ((all-tags (mapcar #'symbol-name
                           (funcall (plist-get adapter :list-all-tags))))
         (choice (completing-read "Tag (RET for all): " all-tags)))
    (total-recall-train--tag-from-choice choice)))

;; ---------------------------------------------------------------------------
;; Session state
;; ---------------------------------------------------------------------------

(defvar-local total-recall-train--session nil
  "Buffer-local session state plist for the training buffer.

Keys:
  :remaining       - list of (item . direction) pairs yet to be current
  :current         - current (item . direction) pair being shown (nil initially)
  :answer-revealed - boolean, whether the answer side is currently visible
  :done            - boolean, session is complete
  :original-total  - total card count at session start
  :results         - hash-table keyed by \"item-id::direction\" → 'correct or 'wrong
  :adapter         - storage adapter plist")

(defun total-recall-train--session-state (queue adapter)
  "Create a session state plist from QUEUE and ADAPTER.

QUEUE is a list of (item-closure . direction-string) pairs as returned
by `total-recall-train--build-queue'.
ADAPTER is a storage adapter plist (see `total-recall-storage-init')."
  (list :remaining (copy-sequence queue)
        :current nil
        :answer-revealed nil
        :done nil
        :original-total (length queue)
        :results (make-hash-table :test 'equal)
        :adapter adapter))

(defun total-recall-train--session-advance (state)
  "Advance STATE to the next card in :remaining.

Returns an updated state plist with :current set to the next card,
:answer-revealed reset to nil, and card removed from :remaining.
If :remaining is empty, sets :done to t and :current to nil."
  (let* ((remaining (plist-get state :remaining))
         (next (car remaining)))
    (if next
        (let ((state (plist-put state :remaining (cdr remaining)))
              (state (plist-put state :current next)))
          (plist-put state :answer-revealed nil))
      ;; No more cards — session complete
      (plist-put (plist-put (plist-put state :current nil) :done t)
                 :answer-revealed nil))))

(defun total-recall-train--session-position (state)
  "Return the current position string like \"N/M\" for STATE."
  (let* ((original (plist-get state :original-total))
         (remaining (plist-get state :remaining))
         (pos (- original (length remaining))))
    (format "%d/%d" pos original)))

(defun total-recall-train--grade-card (state quality)
  "Grade the current card in STATE with QUALITY (0 or 5).

Persists the updated schedule via the adapter.  Quality 5 (correct)
advances to the next card.  Quality 0 (wrong) re-queues the current
card at the end of :remaining before advancing.

Returns an updated state plist."
  (let* ((item-dir (plist-get state :current))
         (item (car item-dir))
         (dir (cdr item-dir))
         (id (funcall item 'get :id))
         (adapter (plist-get state :adapter))
         (schedule (funcall (plist-get adapter :load-schedule) id dir))
         (updated-plist (total-recall-sched--sm2-grade quality schedule))
         (updated-sched (total-recall-make-schedule updated-plist)))
    ;; Persist the updated schedule
    (funcall (plist-get adapter :save-schedule) updated-sched)
    ;; Track the final result per (item-id . direction)
    (let* ((results (plist-get state :results))
           (key (concat id "::" dir)))
      (puthash key (if (= quality 5) 'correct 'wrong) results))
    ;; When wrong, re-queue the card at the end
    (let ((state (if (= quality 0)
                     (let ((remaining (plist-get state :remaining)))
                       (plist-put state :remaining
                                  (append remaining (list item-dir))))
                   state)))
      ;; Advance to the next card
      (total-recall-train--session-advance state))))

;; ---------------------------------------------------------------------------
;; Rendering
;; ---------------------------------------------------------------------------

(defun total-recall-train--render-card (state)
  "Render the current card from STATE into the current buffer."
  (let* ((current (plist-get state :current))
         (item (car current))
         (direction (cdr current))
         (pos (total-recall-train--session-position state))
         (prompt (if (string= direction "forward")
                     (funcall item 'get :term)
                   (funcall item 'get :definition)))
         (answer (if (string= direction "forward")
                     (funcall item 'get :definition)
                   (funcall item 'get :term)))
         (revealed (plist-get state :answer-revealed)))
    (insert (format "═══ [%s] ═══ %s ═══\n\n" pos (capitalize direction)))
    (insert prompt "\n\n")
    (if revealed
        (insert "─── Answer ───\n" answer "\n\n"
                "c correct | w wrong | q quit\n")
      (insert "─── ??? ───\n\n"
              "SPC to reveal | q quit\n"))))

(defun total-recall-train--render-summary (state)
  "Render the session summary from STATE into the current buffer."
  (let* ((results (plist-get state :results))
         (correct 0) (wrong 0))
    (maphash (lambda (_k v)
               (if (eq v 'correct) (cl-incf correct) (cl-incf wrong)))
             results)
    (insert (format "═══ Session Complete ═══\n\nCorrect: %d    Wrong: %d\n\nPress q to close\n"
                    correct wrong))))

(defun total-recall-train--render ()
  "Render the current training state into the current buffer.

Called after every state change to update the display.
Advances to the first card automatically if the session
has just been created and no card is yet current."
  (interactive)
  (let ((state total-recall-train--session))
    (when (and (null (plist-get state :current))
               (not (plist-get state :done)))
      (setq state (total-recall-train--session-advance state))
      (setq-local total-recall-train--session state))
    (when (buffer-live-p (current-buffer))
      (let ((inhibit-read-only t))
        (erase-buffer)
        (if (plist-get state :done)
            (total-recall-train--render-summary state)
          (total-recall-train--render-card state))
        (set-buffer-modified-p nil)))))

;; ---------------------------------------------------------------------------
;; Major mode
;; ---------------------------------------------------------------------------

(defvar total-recall-train-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "SPC") 'total-recall-train-reveal)
    (define-key map "c" 'total-recall-train-correct)
    (define-key map "w" 'total-recall-train-wrong)
    (define-key map "q" 'total-recall-train-quit)
    map)
  "Keymap for `total-recall-train-mode'.")

(define-derived-mode total-recall-train-mode fundamental-mode
  "TotalRecall-Train"
  "Major mode for Total Recall training sessions.

Keybindings:
  SPC  - reveal answer
  c    - grade current card correct
  w    - grade current card wrong
  q    - quit session
\\{total-recall-train-mode-map}"
  (setq buffer-read-only t))

;; ---------------------------------------------------------------------------
;; Interactive commands
;; ---------------------------------------------------------------------------

(defun total-recall-train-reveal ()
  "Reveal the answer side of the current card.

If the answer is already revealed, this is a no-op."
  (interactive)
  (let ((state total-recall-train--session))
    (unless (plist-get state :answer-revealed)
      (setq-local total-recall-train--session
                  (plist-put state :answer-revealed t))
      (total-recall-train--render))))

(defun total-recall-train-correct ()
  "Grade the current card as correct (quality 5).

Has no effect unless the answer has been revealed.
Persists the updated schedule and advances to the next card."
  (interactive)
  (let ((state total-recall-train--session))
    (when (plist-get state :answer-revealed)
      (setq-local total-recall-train--session
                  (total-recall-train--grade-card state 5))
      (total-recall-train--render))))

(defun total-recall-train-wrong ()
  "Grade the current card as wrong (quality 0).

Has no effect unless the answer has been revealed.
Persists the updated schedule, re-queues the card at the
end of the session, and advances."
  (interactive)
  (let ((state total-recall-train--session))
    (when (plist-get state :answer-revealed)
      (setq-local total-recall-train--session
                  (total-recall-train--grade-card state 0))
      (total-recall-train--render))))

(defun total-recall-train-quit ()
  "Quit the current training session and close the buffer."
  (interactive)
  (when (buffer-live-p (current-buffer))
    (kill-buffer (current-buffer))))

;; ---------------------------------------------------------------------------
;; Interactive command factory
;; ---------------------------------------------------------------------------

;;;###autoload
(defun total-recall-train-init (adapter)
  "Return an interactive training command configured with ADAPTER.

ADAPTER is a storage adapter plist (see `total-recall-storage-init').

The returned command prompts for direction and optional tag, builds
the session queue, and enters the training buffer."
  (lambda ()
    "Start a training session interactively.
Prompts for direction and optional tag, builds the session queue,
and enters the training buffer."
    (interactive)
    (let* ((direction (total-recall-train--prompt-direction))
           (tag (total-recall-train--choose-tag adapter))
           (queue (total-recall-train--build-queue adapter direction tag)))
      (if (null queue)
          (message "No items due for review.")
        (let* ((buf (generate-new-buffer "*total-recall-train*"))
               (state (total-recall-train--session-state queue adapter))
               (advanced (total-recall-train--session-advance state)))
          (switch-to-buffer buf)
          (total-recall-train-mode)
          (setq-local total-recall-train--session advanced)
          (total-recall-train--render))))))

;; ---------------------------------------------------------------------------
;; Interactive entry point
;; ---------------------------------------------------------------------------

;;;###autoload
(defun total-recall-train (&optional db-path)
  "Start a training session interactively.

Prompts for direction (forward, backward, both) and an optional tag
filter, builds the session queue of due items, and enters the training
buffer.

Optional DB-PATH overrides `total-recall-train-db-path'.  Pass nil
to use the default (in-memory)."
  (interactive
   (list (or (and current-prefix-arg
                  (read-file-name "Database path: " nil
                                  total-recall-train-db-path nil nil))
             total-recall-train-db-path)))
  (let* ((adapter (total-recall-storage-init (or db-path total-recall-train-db-path)))
         (direction (total-recall-train--prompt-direction))
         (tag (total-recall-train--choose-tag adapter))
         (queue (total-recall-train--build-queue adapter direction tag)))
    (if (null queue)
        (message "No items due for review.")
      (let* ((buf (generate-new-buffer "*total-recall-train*"))
             (state (total-recall-train--session-state queue adapter))
             (advanced (total-recall-train--session-advance state)))
        (switch-to-buffer buf)
        (total-recall-train-mode)
        (setq-local total-recall-train--session advanced)
        (total-recall-train--render)))))

(provide 'total-recall-train)

;;; total-recall-train.el ends here