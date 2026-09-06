;;; test-storage.el --- Tests for total-recall-storage  -*- lexical-binding: t; -*-

(require 'ert)
(require 'total-recall-storage)

(ert-deftest test-storage-init-returns-adapter-plist ()
  "Storage init returns a plist with all required function keys."
  (let ((adapter (total-recall-storage-init nil)))
    (should (listp adapter))
    (dolist (key '(:load-item :save-item :delete-item :load-schedule
                   :save-schedule :query-due :query-by-tag
                   :list-all-tags :query-all))
      (should (functionp (plist-get adapter key)))
      (message "  ✓ adapter has %s" key))))

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
  "Save a schedule then load it by item-id: all fields preserved."
  (let* ((adapter (total-recall-storage-init nil))
         (item (total-recall-make-item '(:term "foo" :definition "bar")))
         (item-id (funcall item 'get :id))
         (sched (total-recall-make-schedule
                 (list :item-id item-id :interval 2.5 :ease-factor 1.8 :repetitions 3 :lapses 0))))
    ;; Save the item first (FK constraint)
    (funcall (plist-get adapter :save-item) item)
    ;; Save schedule
    (funcall (plist-get adapter :save-schedule) sched)
    ;; Load it back
    (let* ((loaded (funcall (plist-get adapter :load-schedule) item-id))
           (orig-data (funcall sched 'serialize))
           (loaded-data (funcall loaded 'serialize)))
      (should loaded)
      (should (equal (plist-get orig-data :item-id) (plist-get loaded-data :item-id)))
      (should (equal (plist-get orig-data :interval) (plist-get loaded-data :interval)))
      (should (equal (plist-get orig-data :ease-factor) (plist-get loaded-data :ease-factor)))
      (should (equal (plist-get orig-data :repetitions) (plist-get loaded-data :repetitions)))
      (should (equal (plist-get orig-data :lapses) (plist-get loaded-data :lapses)))
      (should (equal (plist-get orig-data :next-review) (plist-get loaded-data :next-review))))))

(ert-deftest test-storage-load-nonexistent-schedule ()
  "Load schedule returns nil for item without one."
  (let* ((adapter (total-recall-storage-init nil))
         (item (total-recall-make-item '(:term "foo" :definition "bar")))
         (item-id (funcall item 'get :id)))
    (funcall (plist-get adapter :save-item) item)
    (should (equal (funcall (plist-get adapter :load-schedule) item-id) nil))))

(ert-deftest test-storage-delete-cascades-schedule ()
  "Delete item cascades to remove its schedule."
  (let* ((adapter (total-recall-storage-init nil))
         (item (total-recall-make-item '(:term "foo" :definition "bar")))
         (item-id (funcall item 'get :id))
         (sched (total-recall-make-schedule (list :item-id item-id))))
    (funcall (plist-get adapter :save-item) item)
    (funcall (plist-get adapter :save-schedule) sched)
    ;; Verify schedule exists
    (should (funcall (plist-get adapter :load-schedule) item-id))
    ;; Delete item
    (funcall (plist-get adapter :delete-item) item-id)
    ;; Schedule should be gone
    (should (equal (funcall (plist-get adapter :load-schedule) item-id) nil))))

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