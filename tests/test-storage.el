;;; test-storage.el --- Tests for total-recall-storage  -*- lexical-binding: t; -*-

(require 'ert)
(require 'total-recall-storage)
(require 'cl-lib)

(ert-deftest test-storage-init-returns-adapter-plist ()
  "Storage init returns a plist with all required function keys."
  (let ((adapter (total-recall-storage-init nil)))
    (should (listp adapter))
    (dolist (key '(:load-item :save-item :delete-item :load-schedule
                   :save-schedule :query-due :query-by-tag
                   :list-all-tags :query-all))
      (should (functionp (plist-get adapter key)))
      (message "  ✓ adapter has %s" key))))

(ert-deftest test-storage-schedule-table-has-direction-column ()
  "The schedule table has a direction column and a composite primary key.
SC-2026-09-09_18-29-07-13"
  (let* ((db-path (make-temp-file "tr-schema" nil ".db"))
         (adapter (total-recall-storage-init db-path))
         (db (sqlite-open db-path)))
    (unwind-protect
        (progn
          ;; direction column present, defaults to 'forward'
          (let* ((cols (sqlite-select db "PRAGMA table_info(schedule)"))
                 (col-names (mapcar (lambda (row) (nth 1 row)) cols)))
            (should (member "direction" col-names))
            ;; direction column is NOT NULL with default 'forward'
            (pcase (cl-find "direction" cols
                            :key (lambda (row) (nth 1 row)))
              (`(,_ ,_ ,_ ,notnull ,dflt ,_)
               (should (equal notnull 1))
               ;; SQLite reports the default as the quoted literal 'forward'
               (should (equal dflt "'forward'")))))
          ;; composite primary key (item_id, direction)
          (let* ((cols (sqlite-select db "PRAGMA table_info(schedule)"))
                 (pk (cl-loop for row in cols
                              when (> (nth 5 row) 0)  ; pk > 0 means part of PK
                              collect (nth 1 row))))
            (should (equal (sort pk #'string<) '("direction" "item_id"))))
          ;; only 2 columns are part of the PK
          (let* ((cols (sqlite-select db "PRAGMA table_info(schedule)"))
                 (pk-cols (cl-loop for row in cols
                                   when (> (nth 5 row) 0)
                                   count row)))
            (should (= pk-cols 2))))
      (delete-file db-path))))

;; ---------------------------------------------------------------------------
;; 3.2 — :load-item and :save-item
;; ---------------------------------------------------------------------------

(ert-deftest test-storage-save-then-load-item ()
  "Save an item then load it by id: all fields are preserved."
  (let* ((adapter (total-recall-storage-init nil))
         (item (total-recall-make-item
                '(:term "Hallo" :definition "Hello"
                  :tags (:german :vocabulary)
                  :depth 5
                  :analogy "Similar to \"hello\" in English"
                  :notes "Common greeting used in Germany, Austria, Switzerland")))
         (id (funcall item 'get :id)))
    ;; Save the item
    (funcall (plist-get adapter :save-item) item)
    ;; Load it back
    (let* ((loaded (funcall (plist-get adapter :load-item) id))
           (original-data (funcall item 'serialize))
           (loaded-data (funcall loaded 'serialize)))
      (should loaded)
      (should (equal (plist-get original-data :term) (plist-get loaded-data :term)))
      (should (equal (plist-get original-data :definition) (plist-get loaded-data :definition)))
      (should (equal (plist-get original-data :tags) (plist-get loaded-data :tags)))
      (should (equal (plist-get original-data :depth) (plist-get loaded-data :depth)))
      (should (equal (plist-get original-data :analogy) (plist-get loaded-data :analogy)))
      (should (equal (plist-get original-data :notes) (plist-get loaded-data :notes)))
      (should (equal (plist-get original-data :created) (plist-get loaded-data :created)))
      (should (equal (plist-get original-data :modified) (plist-get loaded-data :modified)))
      (should (equal (plist-get original-data :id) (plist-get loaded-data :id))))))

(ert-deftest test-storage-load-nonexistent-item ()
  "Load returns nil for an item that doesn't exist."
  (let ((adapter (total-recall-storage-init nil)))
    (should (equal (funcall (plist-get adapter :load-item) "nonexistent-id") nil))))

(ert-deftest test-storage-save-updates-existing-item ()
  "Save updates an existing item in-place."
  (let* ((adapter (total-recall-storage-init nil))
         (item (total-recall-make-item '(:term "Hallo" :definition "Hello")))
         (id (funcall item 'get :id)))
    ;; Save, then modify, then save again
    (funcall (plist-get adapter :save-item) item)
    (funcall item 'set :definition "A common greeting")
    (funcall (plist-get adapter :save-item) item)
    ;; Load and verify updated
    (let ((loaded (funcall (plist-get adapter :load-item) id)))
      (should (equal (funcall loaded 'get :definition) "A common greeting")))))

;; ---------------------------------------------------------------------------
;; 3.3 — :delete-item
;; ---------------------------------------------------------------------------

(ert-deftest test-storage-delete-removes-item ()
  "Delete removes the item so loading returns nil."
  (let* ((adapter (total-recall-storage-init nil))
         (item (total-recall-make-item '(:term "Hallo" :definition "Hello")))
         (id (funcall item 'get :id)))
    (funcall (plist-get adapter :save-item) item)
    (funcall (plist-get adapter :delete-item) id)
    (should (equal (funcall (plist-get adapter :load-item) id) nil))))

;; ---------------------------------------------------------------------------
;; 3.4 — :load-schedule and :save-schedule
;; ---------------------------------------------------------------------------

(ert-deftest test-storage-save-then-load-schedule ()
  "Save a schedule then load by item-id and direction: all fields preserved.
SC-2026-09-09_18-29-07-14"
  (let* ((adapter (total-recall-storage-init nil))
         (item (total-recall-make-item '(:term "foo" :definition "bar")))
         (item-id (funcall item 'get :id))
         (sched (total-recall-make-schedule
                 (list :item-id item-id :interval 2.5 :ease-factor 1.8 :repetitions 3 :lapses 0))))
    ;; Save the item first (FK constraint)
    (funcall (plist-get adapter :save-item) item)
    ;; Save schedule
    (funcall (plist-get adapter :save-schedule) sched)
    ;; Load it back with direction
    (let* ((loaded (funcall (plist-get adapter :load-schedule) item-id "forward"))
           (orig-data (funcall sched 'serialize))
           (loaded-data (funcall loaded 'serialize)))
      (should loaded)
      (should (equal (plist-get orig-data :item-id) (plist-get loaded-data :item-id)))
      (should (equal (plist-get orig-data :direction) (plist-get loaded-data :direction)))
      (should (equal (plist-get orig-data :interval) (plist-get loaded-data :interval)))
      (should (equal (plist-get orig-data :ease-factor) (plist-get loaded-data :ease-factor)))
      (should (equal (plist-get orig-data :repetitions) (plist-get loaded-data :repetitions)))
      (should (equal (plist-get orig-data :lapses) (plist-get loaded-data :lapses)))
      (should (equal (plist-get orig-data :next-review) (plist-get loaded-data :next-review))))))

(ert-deftest test-storage-load-schedule-wrong-direction-returns-nil ()
  "Load schedule with wrong direction returns nil.
SC-2026-09-09_18-29-07-15"
  (let* ((adapter (total-recall-storage-init nil))
         (item (total-recall-make-item '(:term "foo" :definition "bar")))
         (item-id (funcall item 'get :id))
         (sched (total-recall-make-schedule (list :item-id item-id :direction "forward"))))
    (funcall (plist-get adapter :save-item) item)
    (funcall (plist-get adapter :save-schedule) sched)
    (should (equal (funcall (plist-get adapter :load-schedule) item-id "backward") nil))))

(ert-deftest test-storage-load-nonexistent-schedule ()
  "Load schedule returns nil for item without one.
SC-2026-09-09_18-29-07-16"
  (let* ((adapter (total-recall-storage-init nil))
         (item (total-recall-make-item '(:term "foo" :definition "bar")))
         (item-id (funcall item 'get :id)))
    (funcall (plist-get adapter :save-item) item)
    (should (equal (funcall (plist-get adapter :load-schedule) item-id "forward") nil))))

(ert-deftest test-storage-forward-backward-coexist ()
  "Forward and backward schedules coexist independently.
SC-2026-09-09_18-29-07-17, SC-2026-09-09_18-29-07-18"
  (let* ((adapter (total-recall-storage-init nil))
         (item (total-recall-make-item '(:term "foo" :definition "bar")))
         (item-id (funcall item 'get :id))
         (fwd (total-recall-make-schedule
               (list :item-id item-id :direction "forward"
                     :interval 1.0 :ease-factor 2.6 :repetitions 1 :lapses 0)))
         (bwd (total-recall-make-schedule
               (list :item-id item-id :direction "backward"
                     :interval 5.0 :ease-factor 2.0 :repetitions 2 :lapses 0))))
    (funcall (plist-get adapter :save-item) item)
    ;; Save forward schedule
    (funcall (plist-get adapter :save-schedule) fwd)
    ;; Save backward schedule
    (funcall (plist-get adapter :save-schedule) bwd)
    ;; Load forward: should get forward data
    (let ((loaded-fwd (funcall (plist-get adapter :load-schedule) item-id "forward")))
      (should loaded-fwd)
      (should (equal (funcall loaded-fwd 'get :interval) 1.0))
      (should (equal (funcall loaded-fwd 'get :direction) "forward")))
    ;; Load backward: should get backward data
    (let ((loaded-bwd (funcall (plist-get adapter :load-schedule) item-id "backward")))
      (should loaded-bwd)
      (should (equal (funcall loaded-bwd 'get :interval) 5.0))
      (should (equal (funcall loaded-bwd 'get :direction) "backward")))))

;; ---------------------------------------------------------------------------
;; Query-due
;; ---------------------------------------------------------------------------

(ert-deftest test-storage-query-due-filters-by-direction ()
  "Query-due returns only items whose schedule for that direction is due.
SC-2026-09-09_18-29-07-19"
  (let* ((adapter (total-recall-storage-init nil))
         (item1 (total-recall-make-item '(:term "due-fwd" :definition "alpha")))
         (item2 (total-recall-make-item '(:term "due-bwd" :definition "beta")))
         (item3 (total-recall-make-item '(:term "due-both" :definition "gamma")))
         (id1 (funcall item1 'get :id))
         (id2 (funcall item2 'get :id))
         (id3 (funcall item3 'get :id))
         (past "2000-01-01T00:00:00.000000+0000")
         (future "2999-01-01T00:00:00.000000+0000"))
    (funcall (plist-get adapter :save-item) item1)
    (funcall (plist-get adapter :save-item) item2)
    (funcall (plist-get adapter :save-item) item3)
    ;; item1: fwd due, bwd not due
    (funcall (plist-get adapter :save-schedule)
             (total-recall-make-schedule
              (list :item-id id1 :direction "forward" :next-review past)))
    (funcall (plist-get adapter :save-schedule)
             (total-recall-make-schedule
              (list :item-id id1 :direction "backward" :next-review future)))
    ;; item2: fwd not due, bwd due
    (funcall (plist-get adapter :save-schedule)
             (total-recall-make-schedule
              (list :item-id id2 :direction "forward" :next-review future)))
    (funcall (plist-get adapter :save-schedule)
             (total-recall-make-schedule
              (list :item-id id2 :direction "backward" :next-review past)))
    ;; item3: both due
    (funcall (plist-get adapter :save-schedule)
             (total-recall-make-schedule
              (list :item-id id3 :direction "forward" :next-review past)))
    (funcall (plist-get adapter :save-schedule)
             (total-recall-make-schedule
              (list :item-id id3 :direction "backward" :next-review past)))
    ;; forward due: item1 and item3
    (let ((fwd-due (funcall (plist-get adapter :query-due) "forward")))
      (should (= (length fwd-due) 2))
      (should (member id1 (mapcar (lambda (r) (funcall r 'get :id)) fwd-due)))
      (should (member id3 (mapcar (lambda (r) (funcall r 'get :id)) fwd-due))))
    ;; backward due: item2 and item3
    (let ((bwd-due (funcall (plist-get adapter :query-due) "backward")))
      (should (= (length bwd-due) 2))
      (should (member id2 (mapcar (lambda (r) (funcall r 'get :id)) bwd-due)))
      (should (member id3 (mapcar (lambda (r) (funcall r 'get :id)) bwd-due))))))

(ert-deftest test-storage-query-due-empty ()
  "Query-due returns empty when no items are due for that direction.
SC-2026-09-09_18-29-07-20"
  (let* ((adapter (total-recall-storage-init nil))
         (item (total-recall-make-item '(:term "foo" :definition "bar")))
         (item-id (funcall item 'get :id))
         (future "2999-01-01T00:00:00.000000+0000"))
    (funcall (plist-get adapter :save-item) item)
    (funcall (plist-get adapter :save-schedule)
             (total-recall-make-schedule
              (list :item-id item-id :direction "forward" :next-review future)))
    (should (equal (funcall (plist-get adapter :query-due) "forward") nil))))

(ert-deftest test-storage-delete-cascades-schedule ()
  "Delete item cascades to remove both schedule directions.
SC-2026-09-09_18-29-07-21"
  (let* ((adapter (total-recall-storage-init nil))
         (item (total-recall-make-item '(:term "foo" :definition "bar")))
         (item-id (funcall item 'get :id))
         (fwd (total-recall-make-schedule
               (list :item-id item-id :direction "forward")))
         (bwd (total-recall-make-schedule
               (list :item-id item-id :direction "backward"))))
    (funcall (plist-get adapter :save-item) item)
    (funcall (plist-get adapter :save-schedule) fwd)
    (funcall (plist-get adapter :save-schedule) bwd)
    ;; Verify both schedules exist
    (should (funcall (plist-get adapter :load-schedule) item-id "forward"))
    (should (funcall (plist-get adapter :load-schedule) item-id "backward"))
    ;; Delete item
    (funcall (plist-get adapter :delete-item) item-id)
    ;; Both schedule directions should be gone
    (should (equal (funcall (plist-get adapter :load-schedule) item-id "forward") nil))
    (should (equal (funcall (plist-get adapter :load-schedule) item-id "backward") nil))))

;; ---------------------------------------------------------------------------
;; 3.5 — :query-all
;; ---------------------------------------------------------------------------

(ert-deftest test-storage-query-all-returns-all-ids ()
  "Query-all returns ids of all saved items."
  (let* ((adapter (total-recall-storage-init nil))
         (item1 (total-recall-make-item '(:term "a" :definition "A")))
         (item2 (total-recall-make-item '(:term "b" :definition "B")))
         (item3 (total-recall-make-item '(:term "c" :definition "C")))
         (id1 (funcall item1 'get :id))
         (id2 (funcall item2 'get :id))
         (id3 (funcall item3 'get :id)))
    (funcall (plist-get adapter :save-item) item1)
    (funcall (plist-get adapter :save-item) item2)
    (funcall (plist-get adapter :save-item) item3)
    (let ((ids (funcall (plist-get adapter :query-all))))
      (should (= (length ids) 3))
      (should (member id1 ids))
      (should (member id2 ids))
      (should (member id3 ids)))))

(ert-deftest test-storage-query-all-empty ()
  "Query-all returns empty list when no items exist."
  (let ((adapter (total-recall-storage-init nil)))
    (should (equal (funcall (plist-get adapter :query-all)) nil))))

;; ---------------------------------------------------------------------------
;; 3.6 — :query-by-tag
;; ---------------------------------------------------------------------------

(ert-deftest test-storage-query-by-tag-returns-matching ()
  "Query-by-tag returns items that have the given tag."
  (let* ((adapter (total-recall-storage-init nil))
         (item1 (total-recall-make-item '(:term "Hallo" :definition "Hello" :tags (:german :vocabulary))))
         (item2 (total-recall-make-item '(:term "Adieu" :definition "Goodbye" :tags (:german :vocabulary))))
         (item3 (total-recall-make-item '(:term "Bonjour" :definition "Hello" :tags (:french :vocabulary))))
         (id1 (funcall item1 'get :id))
         (id2 (funcall item2 'get :id)))
    (funcall (plist-get adapter :save-item) item1)
    (funcall (plist-get adapter :save-item) item2)
    (funcall (plist-get adapter :save-item) item3)
    (let ((results (funcall (plist-get adapter :query-by-tag) :german)))
      (should (= (length results) 2))
      (should (member id1 (mapcar (lambda (r) (funcall r 'get :id)) results)))
      (should (member id2 (mapcar (lambda (r) (funcall r 'get :id)) results)))
      ;; French item should not be present
      (should-not (member (funcall item3 'get :id)
                          (mapcar (lambda (r) (funcall r 'get :id)) results))))))

(ert-deftest test-storage-query-by-tag-no-matches ()
  "Query-by-tag returns empty list when no item has the tag."
  (let* ((adapter (total-recall-storage-init nil))
         (item (total-recall-make-item '(:term "foo" :definition "bar" :tags (:german))))
         (item2 (total-recall-make-item '(:term "baz" :definition "qux" :tags (:french)))))
    (funcall (plist-get adapter :save-item) item)
    (funcall (plist-get adapter :save-item) item2)
    (should (equal (funcall (plist-get adapter :query-by-tag) :spanish) nil))))

;; ---------------------------------------------------------------------------
;; 3.7 — :list-all-tags
;; ---------------------------------------------------------------------------

(ert-deftest test-storage-list-all-tags-returns-distinct ()
  "List-all-tags returns every distinct tag across items."
  (let* ((adapter (total-recall-storage-init nil))
         (item1 (total-recall-make-item '(:term "Hallo" :definition "Hello" :tags (:german :vocabulary))))
         (item2 (total-recall-make-item '(:term "Bonjour" :definition "Hello" :tags (:french :vocabulary)))))
    (funcall (plist-get adapter :save-item) item1)
    (funcall (plist-get adapter :save-item) item2)
    (let ((tags (funcall (plist-get adapter :list-all-tags))))
      (should (= (length tags) 3))
      (should (member :german tags))
      (should (member :french tags))
      (should (member :vocabulary tags)))))

(ert-deftest test-storage-list-all-tags-collapses-duplicates ()
  "Duplicate tags across items are collapsed to one."
  (let* ((adapter (total-recall-storage-init nil))
         (item1 (total-recall-make-item '(:term "Hallo" :definition "Hello" :tags (:german))))
         (item2 (total-recall-make-item '(:term "Tschüss" :definition "Bye" :tags (:german)))))
    (funcall (plist-get adapter :save-item) item1)
    (funcall (plist-get adapter :save-item) item2)
    (let ((tags (funcall (plist-get adapter :list-all-tags))))
      (should (= (length tags) 1))
      (should (equal tags '(:german))))))

(ert-deftest test-storage-list-all-tags-empty ()
  "List-all-tags returns nil when no items have tags."
  (let* ((adapter (total-recall-storage-init nil))
         (item (total-recall-make-item '(:term "foo" :definition "bar"))))
    (funcall (plist-get adapter :save-item) item)
    (should (equal (funcall (plist-get adapter :list-all-tags)) nil))))

(provide 'test-storage)
;;; test-storage.el ends here