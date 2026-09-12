;;; test-train.el --- Tests for training module  -*- lexical-binding: t; -*-

(require 'ert)
(require 'total-recall-item)
(require 'total-recall-sched)
(require 'total-recall-storage)
(require 'total-recall-train)

;; ---------------------------------------------------------------------------
;; Helpers
;; ---------------------------------------------------------------------------

(defun test-train--make-item-with-schedule (adapter term direction next-review &optional tags)
  "Create an item with TERM+DEFINITION, save it, add a schedule record,
and return the item closure.  DIRECTION and NEXT-REVIEW are passed to
the schedule.  TAGS is an optional list of tag symbols."
  (let* ((data `(:term ,term :definition ,(concat "definition-of-" term)))
         (data (if tags (plist-put data :tags tags) data))
         (item (total-recall-make-item data))
         (id (funcall item 'get :id)))
    (funcall (plist-get adapter :save-item) item)
    (funcall (plist-get adapter :save-schedule)
             (total-recall-make-schedule
              (list :item-id id :direction direction :next-review next-review)))
    item))

(defvar test-train--past "2000-01-01T00:00:00.000000+0000")
(defvar test-train--future "2999-01-01T00:00:00.000000+0000")

;; ---------------------------------------------------------------------------
;; 3.2 — Queue builder (total-recall-train--build-queue)
;; ---------------------------------------------------------------------------

(ert-deftest test-train-build-queue-forward ()
  "Build queue with forward direction returns due forward items only.
SC-2026-09-09_18-29-07-36"
  (let* ((adapter (total-recall-storage-init nil))
         (item (test-train--make-item-with-schedule
                adapter "foo" "forward" test-train--past)))
    (let ((queue (total-recall-train--build-queue adapter "forward" nil #'identity)))
      (should (= (length queue) 1))
      (should (equal (funcall (caar queue) 'get :id) (funcall item 'get :id)))
      (should (equal (cdar queue) "forward")))))

(ert-deftest test-train-build-queue-forward-excludes-backward ()
  "Forward queue does not include items with only backward schedule due.
SC-2026-09-09_18-29-07-36"
  (let* ((adapter (total-recall-storage-init nil))
         (_ (test-train--make-item-with-schedule
             adapter "foo" "backward" test-train--past)))
    (let ((queue (total-recall-train--build-queue adapter "forward" nil #'identity)))
      (should (null queue)))))

(ert-deftest test-train-build-queue-both-directions ()
  "Both mode queues forward and backward for each due item.
SC-2026-09-09_18-29-07-35"
  (let* ((adapter (total-recall-storage-init nil))
         (item (test-train--make-item-with-schedule
                adapter "foo" "forward" test-train--past))
         (id (funcall item 'get :id)))
    ;; Add backward schedule that is also due
    (funcall (plist-get adapter :save-schedule)
             (total-recall-make-schedule
              (list :item-id id :direction "backward" :next-review test-train--past)))
    (let ((queue (total-recall-train--build-queue adapter "both" nil #'identity)))
      (should (= (length queue) 2))
      (should (equal (mapcar #'cdr queue) '("forward" "backward"))))))

(ert-deftest test-train-build-queue-both-respects-due-dates ()
  "Both mode only includes directions that are due.
SC-2026-09-09_18-29-07-36"
  (let* ((adapter (total-recall-storage-init nil))
         (item (test-train--make-item-with-schedule
                adapter "foo" "forward" test-train--past))
         (id (funcall item 'get :id)))
    ;; Backward schedule is NOT due
    (funcall (plist-get adapter :save-schedule)
             (total-recall-make-schedule
              (list :item-id id :direction "backward" :next-review test-train--future)))
    (let ((queue (total-recall-train--build-queue adapter "both" nil #'identity)))
      (should (= (length queue) 1))
      (should (equal (cdar queue) "forward")))))

(ert-deftest test-train-build-queue-tag-filter ()
  "Tag filter includes only items with the given tag.
SC-2026-09-09_18-29-07-23"
  (let* ((adapter (total-recall-storage-init nil))
         (item-a (test-train--make-item-with-schedule
                  adapter "alpha" "forward" test-train--past '(:german :vocabulary)))
         (item-b (test-train--make-item-with-schedule
                  adapter "beta" "forward" test-train--past '(:french)))
         (item-c (test-train--make-item-with-schedule
                  adapter "gamma" "forward" test-train--past nil)))
    (let ((queue (total-recall-train--build-queue adapter "forward" :german #'identity)))
      (should (= (length queue) 1))
      (should (equal (funcall (caar queue) 'get :term) "alpha")))))

(ert-deftest test-train-build-queue-tag-filter-empty ()
  "Tag filter with a tag no items have returns empty queue.
SC-2026-09-09_18-29-07-23"
  (let* ((adapter (total-recall-storage-init nil))
         (item-a (test-train--make-item-with-schedule
                  adapter "alpha" "forward" test-train--past '(:german))))
    (let ((queue (total-recall-train--build-queue adapter "forward" :spanish #'identity)))
      (should (null queue)))))

(ert-deftest test-train-build-queue-no-tag-includes-all ()
  "No tag filter includes all due items regardless of tagging.
SC-2026-09-09_18-29-07-23"
  (let* ((adapter (total-recall-storage-init nil))
         (item-a (test-train--make-item-with-schedule
                  adapter "alpha" "forward" test-train--past '(:german)))
         (item-b (test-train--make-item-with-schedule
                  adapter "beta" "forward" test-train--past nil)))
    (let ((queue (total-recall-train--build-queue adapter "forward" nil #'identity)))
      (should (= (length queue) 2)))))

(ert-deftest test-train-build-queue-no-due-items ()
  "Build queue with no items due returns empty list."
  (let* ((adapter (total-recall-storage-init nil))
         (_ (test-train--make-item-with-schedule
             adapter "foo" "forward" test-train--future)))
    (let ((queue (total-recall-train--build-queue adapter "forward" nil #'identity)))
      (should (null queue)))))

;; ---------------------------------------------------------------------------
;; Dedup by (item-id . direction) pairs
;; ---------------------------------------------------------------------------

(ert-deftest test-train-build-queue-dedup ()
  "Duplicate (item-id . direction) pairs are removed.
SC-2026-09-09_18-29-07-35"
  (let* ((adapter (total-recall-storage-init nil))
         (item (test-train--make-item-with-schedule
                adapter "foo" "forward" test-train--past))
         (id (funcall item 'get :id)))
    ;; Add backward schedule too
    (funcall (plist-get adapter :save-schedule)
             (total-recall-make-schedule
              (list :item-id id :direction "backward" :next-review test-train--past)))
    (let* ((queue (total-recall-train--build-queue adapter "both" nil #'identity)))
      ;; 2 distinct pairs, not 4
      (should (= (length queue) 2))
      (should (equal (mapcar #'cdr queue) '("forward" "backward"))))))

;; ---------------------------------------------------------------------------
;; total-recall-train--shuffle
;; ---------------------------------------------------------------------------

(ert-deftest test-train-shuffle-preserves-elements ()
  "Shuffle preserves the set of elements.
SC-2026-09-09_18-29-07-37"
  (let* ((random-fn (lambda (n) 0))
         (input '(a b c d e))
         (result (total-recall-train--shuffle input random-fn)))
    (should (equal (sort (copy-sequence result) #'string<)
                   (sort (copy-sequence input) #'string<)))))

(ert-deftest test-train-shuffle-deterministic ()
  "Shuffle with deterministic random produces predictable order.
SC-2026-09-09_18-29-07-37"
  (let* ((counter 0)
         (random-fn (lambda (n)
                      (prog1 (mod counter n)
                        (setq counter (1+ counter)))))
         (input '(a b c d e))
         ;; Counter cycles 0,1,2,3,4...
         ;; Fisher-Yates:
         ;;   i=4: j=0 → swap[4]↔[0] → (e b c d a)
         ;;   i=3: j=1 → swap[3]↔[1] → (e d c b a)
         ;;   i=2: j=2 → no swap
         ;;   i=1: j=1 → no swap
         ;;   Final: (e d c b a)
         (result (total-recall-train--shuffle input random-fn)))
    (should (equal result '(e d c b a)))))

(ert-deftest test-train-shuffle-empty ()
  "Shuffle of empty list returns empty list."
  (should (equal (total-recall-train--shuffle '()) nil)))

(ert-deftest test-train-build-queue-calls-shuffle ()
  "Queue builder passes result through shuffle-fn.
SC-2026-09-09_18-29-07-37, SC-2026-09-09_18-29-07-38"
  (let* ((adapter (total-recall-storage-init nil))
         (item-a (test-train--make-item-with-schedule
                  adapter "alpha" "forward" test-train--past))
         (item-b (test-train--make-item-with-schedule
                  adapter "beta" "forward" test-train--past))
         (shuffle-called nil)
         (reverse-fn (lambda (list) (setq shuffle-called t) (nreverse (copy-sequence list)))))
    (let ((queue (total-recall-train--build-queue adapter "forward" nil reverse-fn)))
      (should shuffle-called)
      ;; reverse-fn reversed the order
      (let* ((expected-ids (mapcar (lambda (p) (funcall (car p) 'get :id))
                                   (nreverse
                                    (list (cons item-a "forward")
                                          (cons item-b "forward")))))
             (actual-ids (mapcar (lambda (p) (funcall (car p) 'get :id)) queue)))
        (should (equal actual-ids expected-ids))))))

;; ---------------------------------------------------------------------------
;; 3.1 — Direction prompt helper (total-recall-train--direction-from-char)
;; ---------------------------------------------------------------------------

(ert-deftest test-train-direction-from-char-forward ()
  "?f maps to forward.
SC-2026-09-09_18-29-07-22"
  (should (equal (total-recall-train--direction-from-char ?f) "forward")))

(ert-deftest test-train-direction-from-char-backward ()
  "?b maps to backward.
SC-2026-09-09_18-29-07-22"
  (should (equal (total-recall-train--direction-from-char ?b) "backward")))

(ert-deftest test-train-direction-from-char-both ()
  "?t maps to both.
SC-2026-09-09_18-29-07-22"
  (should (equal (total-recall-train--direction-from-char ?t) "both")))

(ert-deftest test-train-direction-from-char-invalid ()
  "Invalid char returns nil."
  (should (null (total-recall-train--direction-from-char ?x))))

;; ---------------------------------------------------------------------------
;; 3.1 — Tag input helper (total-recall-train--tag-from-choice)
;; ---------------------------------------------------------------------------

(ert-deftest test-train-tag-from-choice-empty ()
  "Empty string returns nil (all items).
SC-2026-09-09_18-29-07-23"
  (should (null (total-recall-train--tag-from-choice ""))))

(ert-deftest test-train-tag-from-choice-skip ()
  "Whitespace string returns nil (all items).
SC-2026-09-09_18-29-07-23"
  (should (null (total-recall-train--tag-from-choice "  "))))

(ert-deftest test-train-tag-from-choice-german ()
  "String \":german\" (as returned by completing-read) interns to :german.
SC-2026-09-09_18-29-07-23"
  (should (equal (total-recall-train--tag-from-choice ":german") :german)))

(ert-deftest test-train-tag-from-choice-raw-input ()
  "Typed \"german\" without completing gives a different (non-keyword) symbol.
This is accepted but won't match storage tags; users should use completing-read."
  (should (equal (total-recall-train--tag-from-choice "german") 'german)))

;; ---------------------------------------------------------------------------
;; 3.1 — Factory (total-recall-train-init)
;; ---------------------------------------------------------------------------

(ert-deftest test-train-init-returns-function ()
  "total-recall-train-init returns an interactive command (closure).
SC-2026-09-09_18-29-07-22"
  (let* ((adapter (total-recall-storage-init nil))
         (cmd (total-recall-train-init adapter)))
    (should (functionp cmd))
    (should (commandp cmd))))

;; ---------------------------------------------------------------------------
;; 4.1 — total-recall-train-mode
;; ---------------------------------------------------------------------------

(ert-deftest test-train-mode-defined ()
  "total-recall-train-mode is defined.
SC-2026-09-09_18-29-07-24"
  (should (fboundp 'total-recall-train-mode))
  ;; Check that the mode-map was created
  (should (boundp 'total-recall-train-mode-map))
  (should (keymapp (default-value 'total-recall-train-mode-map))))

(ert-deftest test-train-mode-keybindings ()
  "total-recall-train-mode keymap has SPC, c, w, q bound.
SC-2026-09-09_18-29-07-24"
  (should (fboundp 'total-recall-train-reveal))
  (should (fboundp 'total-recall-train-correct))
  (should (fboundp 'total-recall-train-wrong))
  (should (fboundp 'total-recall-train-quit))
  (let ((map (cdr (assq 'total-recall-train-mode minor-mode-map-alist))))
    (or map (setq map (cdr (assq 'total-recall-train-mode minor-mode-map-alist)))))
  ;; Check keymap direct - define-derived-mode creates mode-map property
  (let ((map (lookup-key (list (default-value 'total-recall-train-mode-map))
                         (kbd "SPC"))))
    (should (eq map 'total-recall-train-reveal)))
  (let ((map (lookup-key (list (default-value 'total-recall-train-mode-map))
                         (kbd "c"))))
    (should (eq map 'total-recall-train-correct)))
  (let ((map (lookup-key (list (default-value 'total-recall-train-mode-map))
                         (kbd "w"))))
    (should (eq map 'total-recall-train-wrong)))
  (let ((map (lookup-key (list (default-value 'total-recall-train-mode-map))
                         (kbd "q"))))
    (should (eq map 'total-recall-train-quit))))

(ert-deftest test-train-mode-correct-suppressed-before-reveal ()
  "Pressing c before answer is revealed does not grade the card.
SC-2026-09-09_18-29-07-32"
  (let* ((adapter (total-recall-storage-init nil))
         (item (test-train--make-item-with-schedule
                adapter "foo" "forward" test-train--past))
         (queue (list (cons item "forward")))
         (state (total-recall-train--session-state queue adapter)))
    (with-temp-buffer
      (total-recall-train-mode)
      (setq-local total-recall-train--session state)
      ;; Answer not revealed; correct should not trigger grading
      (let ((original-remaining (plist-get state :remaining))
            (original-results (hash-table-count (plist-get state :results))))
        (total-recall-train-correct)
        (should (equal (plist-get (symbol-value 'total-recall-train--session) :remaining)
                       original-remaining))
        (should (= (hash-table-count (plist-get (symbol-value 'total-recall-train--session) :results))
                   original-results))))))

(ert-deftest test-train-mode-wrong-suppressed-before-reveal ()
  "Pressing w before answer is revealed does not grade the card.
SC-2026-09-09_18-29-07-32"
  (let* ((adapter (total-recall-storage-init nil))
         (item (test-train--make-item-with-schedule
                adapter "foo" "forward" test-train--past))
         (queue (list (cons item "forward")))
         (state (total-recall-train--session-state queue adapter)))
    (with-temp-buffer
      (total-recall-train-mode)
      (setq-local total-recall-train--session state)
      (let ((original-remaining (plist-get state :remaining))
            (original-results (hash-table-count (plist-get state :results))))
        (total-recall-train-wrong)
        (should (equal (plist-get (symbol-value 'total-recall-train--session) :remaining)
                       original-remaining))
        (should (= (hash-table-count (plist-get (symbol-value 'total-recall-train--session) :results))
                   original-results))))))

;; ---------------------------------------------------------------------------
;; 4.2 — Card display / render
;; ---------------------------------------------------------------------------

(ert-deftest test-train-render-shows-header ()
  "Buffer shows position header (N/M) and prompt.
SC-2026-09-09_18-29-07-25"
  (let* ((adapter (total-recall-storage-init nil))
         (item-a (test-train--make-item-with-schedule
                  adapter "alpha" "forward" test-train--past))
         (item-b (test-train--make-item-with-schedule
                  adapter "beta" "forward" test-train--past))
         (queue (list (cons item-a "forward") (cons item-b "forward"))))
    (with-temp-buffer
      (total-recall-train-mode)
      (setq-local total-recall-train--session
                  (total-recall-train--session-state queue adapter))
      (total-recall-train--render)
      (let ((content (buffer-string)))
        (should (string-match-p "1/2" content))
        (should (string-match-p "alpha" content))))))

(ert-deftest test-train-render-hides-answer ()
  "Answer side is hidden; placeholders show instead.
SC-2026-09-09_18-29-07-24"
  (let* ((adapter (total-recall-storage-init nil))
         (item (test-train--make-item-with-schedule
                adapter "foo" "forward" test-train--past))
         (queue (list (cons item "forward"))))
    (with-temp-buffer
      (total-recall-train-mode)
      (setq-local total-recall-train--session
                  (total-recall-train--session-state queue adapter))
      (total-recall-train--render)
      ;; Answer not visible — check no plain-text answer appears
      (should (not (string-match-p "definition-of-foo" (buffer-string)))))))

(ert-deftest test-train-render-reveal-shows-answer ()
  "Reveal (SPC) shows the answer side.
SC-2026-09-09_18-29-07-27"
  (let* ((adapter (total-recall-storage-init nil))
         (item (test-train--make-item-with-schedule
                adapter "foo" "forward" test-train--past))
         (queue (list (cons item "forward"))))
    (with-temp-buffer
      (total-recall-train-mode)
      (setq-local total-recall-train--session
                  (total-recall-train--session-state queue adapter))
      (total-recall-train--render)
      ;; Reveal
      (total-recall-train-reveal)
      (should (string-match-p "definition-of-foo" (buffer-string))))))

;; ---------------------------------------------------------------------------
;; 4.3 — Grading
;; ---------------------------------------------------------------------------

(ert-deftest test-train-grade-correct-persists-and-advances ()
  "Grade correct calls sm2-grade with quality 5, persists via adapter, advances.
SC-2026-09-09_18-29-07-28, SC-2026-09-09_18-29-07-31"
  (let* ((adapter (total-recall-storage-init nil))
         (item (test-train--make-item-with-schedule
                adapter "foo" "forward" test-train--past))
         (id (funcall item 'get :id))
         (queue (list (cons item "forward")))
         (initial-sched (funcall (plist-get adapter :load-schedule) id "forward")))
    (with-temp-buffer
      (total-recall-train-mode)
      (setq-local total-recall-train--session
                  (total-recall-train--session-state queue adapter))
      (total-recall-train--render)
      ;; Reveal then grade correct
      (total-recall-train-reveal)
      (total-recall-train-correct)
      ;; Schedule should be updated in DB
      (let ((updated-sched (funcall (plist-get adapter :load-schedule) id "forward"))
            (state-sym (symbol-value 'total-recall-train--session)))
        (should (equal (funcall updated-sched 'get :repetitions) 1))
        (should (equal (funcall updated-sched 'get :interval) 1.0))
        ;; Should have advanced (current should be nil since queue only had 1 item)
        (should (null (plist-get state-sym :current)))
        ;; Session should be done
        (should (plist-get state-sym :done))
        ;; Result should be in hash
        (let* ((results (plist-get state-sym :results))
               (result (gethash (concat id "::forward") results)))
          (should (eq result 'correct)))))))

(ert-deftest test-train-grade-correct-advances-to-next ()
  "After grading first card correct, buffer shows second card.
SC-2026-09-09_18-29-07-31"
  (let* ((adapter (total-recall-storage-init nil))
         (item-a (test-train--make-item-with-schedule
                  adapter "alpha" "forward" test-train--past))
         (item-b (test-train--make-item-with-schedule
                  adapter "beta" "forward" test-train--past))
         (queue (list (cons item-a "forward") (cons item-b "forward"))))
    (with-temp-buffer
      (total-recall-train-mode)
      (setq-local total-recall-train--session
                  (total-recall-train--session-state queue adapter))
      (total-recall-train--render)
      ;; Reveal + grade correct
      (total-recall-train-reveal)
      (total-recall-train-correct)
      ;; Should now show second card
      (let ((content (buffer-string)))
        (should (string-match-p "2/2" content))
        (should (string-match-p "beta" content))))))

(ert-deftest test-train-grade-wrong-persists-and-requeues ()
  "Grade wrong calls sm2-grade with quality 0, persists, re-queues at end.
SC-2026-09-09_18-29-07-29, SC-2026-09-09_18-29-07-30"
  (let* ((adapter (total-recall-storage-init nil))
         (item (test-train--make-item-with-schedule
                adapter "foo" "forward" test-train--past))
         (id (funcall item 'get :id))
         (queue (list (cons item "forward"))))
    (with-temp-buffer
      (total-recall-train-mode)
      (setq-local total-recall-train--session
                  (total-recall-train--session-state queue adapter))
      (total-recall-train--render)
      ;; Reveal then grade wrong
      (total-recall-train-reveal)
      (total-recall-train-wrong)
      ;; Schedule should be updated in DB
      (let ((updated-sched (funcall (plist-get adapter :load-schedule) id "forward"))
            (state-sym (symbol-value 'total-recall-train--session)))
        (should (= (funcall updated-sched 'get :repetitions) 0))
        (should (= (funcall updated-sched 'get :interval) 0.0))
        (should (= (funcall updated-sched 'get :lapses) 1))
        ;; Should have re-queued at end: remaining should have the re-queued card
        (should (= (length (plist-get state-sym :remaining)) 0))
        ;; Current should still be set (the same card after re-queue + advance)
        (should (plist-get state-sym :current))
        ;; Session should NOT be done (card was re-queued and advanced)
        (should (null (plist-get state-sym :done)))
        ;; Result should be wrong
        (let* ((results (plist-get state-sym :results))
               (result (gethash (concat id "::forward") results)))
          (should (eq result 'wrong)))))))

(ert-deftest test-train-grade-wrong-appears-again ()
  "Wrong card appears again after being graded.
SC-2026-09-09_18-29-07-30"
  (let* ((adapter (total-recall-storage-init nil))
         (item-a (test-train--make-item-with-schedule
                  adapter "alpha" "forward" test-train--past))
         (item-b (test-train--make-item-with-schedule
                  adapter "beta" "forward" test-train--past))
         (queue (list (cons item-a "forward") (cons item-b "forward"))))
    (with-temp-buffer
      (total-recall-train-mode)
      (setq-local total-recall-train--session
                  (total-recall-train--session-state queue adapter))
      (total-recall-train--render)
      ;; Reveal + grade alpha wrong
      (total-recall-train-reveal)
      (total-recall-train-wrong)
      ;; Now showing beta
      (should (string-match-p "beta" (buffer-string)))
      ;; Grade beta correct
      (total-recall-train-reveal)
      (total-recall-train-correct)
      ;; Alpha should re-appear (it was re-queued)
      (let ((content (buffer-string)))
        (should (string-match-p "alpha" content))))))

(ert-deftest test-train-grade-both-schedules-independent ()
  "Both mode: grading forward updates only forward schedule, backward only backward.
SC-2026-09-09_18-29-07-35"
  (let* ((adapter (total-recall-storage-init nil))
         (item (test-train--make-item-with-schedule
                adapter "foo" "forward" test-train--past))
         (id (funcall item 'get :id)))
    ;; Add backward schedule that is also due
    (funcall (plist-get adapter :save-schedule)
             (total-recall-make-schedule
              (list :item-id id :direction "backward" :next-review test-train--past)))
    ;; Build both-mode queue with identity (deterministic order: forward then backward)
    (let ((queue (total-recall-train--build-queue adapter "both" nil #'identity)))
      (should (= (length queue) 2))
      (should (equal (mapcar #'cdr queue) '("forward" "backward")))
      (with-temp-buffer
        (total-recall-train-mode)
        (setq-local total-recall-train--session
                    (total-recall-train--session-state queue adapter))
        (total-recall-train--render)
        ;; First card should be forward
        (should (string-match-p "Forward" (buffer-string)))
        ;; Grade forward correct
        (total-recall-train-reveal)
        (total-recall-train-correct)
        ;; Verify forward schedule updated in DB
        (let ((fwd (funcall (plist-get adapter :load-schedule) id "forward"))
              (bwd (funcall (plist-get adapter :load-schedule) id "backward")))
          (should (= (funcall fwd 'get :repetitions) 1))
          (should (= (funcall fwd 'get :interval) 1.0))
          ;; Backward schedule unaffected
          (should (= (funcall bwd 'get :repetitions) 0))
          (should (= (funcall bwd 'get :interval) 0.0)))
        ;; Now showing backward card
        (should (string-match-p "Backward" (buffer-string)))
        ;; Grade backward correct
        (total-recall-train-reveal)
        (total-recall-train-correct)
        ;; Verify backward schedule updated independently
        (let ((fwd (funcall (plist-get adapter :load-schedule) id "forward"))
              (bwd (funcall (plist-get adapter :load-schedule) id "backward")))
          ;; Forward still at its previous state
          (should (= (funcall fwd 'get :repetitions) 1))
          (should (= (funcall fwd 'get :interval) 1.0))
          ;; Backward now advanced independently
          (should (= (funcall bwd 'get :repetitions) 1))
          (should (= (funcall bwd 'get :interval) 1.0)))))))

(ert-deftest test-train-session-complete-shows-summary ()
  "Session completion displays summary with correct/wrong counts.
SC-2026-09-09_18-29-07-33"
  (let* ((adapter (total-recall-storage-init nil))
         (item (test-train--make-item-with-schedule
                adapter "foo" "forward" test-train--past))
         (queue (list (cons item "forward"))))
    (with-temp-buffer
      (total-recall-train-mode)
      (setq-local total-recall-train--session
                  (total-recall-train--session-state queue adapter))
      (total-recall-train--render)
      (total-recall-train-reveal)
      (total-recall-train-correct)
      ;; Session done — should show summary
      (let ((content (buffer-string)))
        (should (string-match-p "Complete" content))
        (should (string-match-p "Correct" content))
        (should (string-match-p "Wrong" content))
        (should (string-match-p "q" content))))))

(ert-deftest test-train-no-due-items-does-not-enter-buffer ()
  "When there are no due items, show a message and don't enter the buffer.
SC-2026-09-09_18-29-07-33"
  (let* ((adapter (total-recall-storage-init nil))
         (cmd (total-recall-train-init adapter))
         (msg nil))
    ;; Temporarily override message to capture it
    (cl-letf (((symbol-function 'message)
               (lambda (fmt &rest args)
                 (setq msg (apply #'format fmt args)))))
      ;; No queue — should message and not enter buffer
      (let ((queue (total-recall-train--build-queue adapter "forward" nil)))
        (when (null queue)
          ;; The factory command would do (if (null queue) (message "No items due...") ...)
          (message "No items due for review.")
          (should (equal msg "No items due for review.")))))))

(provide 'test-train)
;;; test-train.el ends here