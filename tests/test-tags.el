;;; test-tags.el --- Tests for total-recall-tags  -*- lexical-binding: t; -*-

(require 'ert)
(require 'total-recall-item)
(require 'total-recall-tags)

;; ---------------------------------------------------------------------------
;; 4.1 — total-recall-tag--add
;; ---------------------------------------------------------------------------

(ert-deftest test-tag-add-single ()
  "Add a single tag to an item."
  (let ((item (total-recall-make-item '(:term "Hallo" :definition "Hello"))))
    (total-recall-tag--add item :german)
    (should (equal (funcall item 'get :tags) '(:german)))))

(ert-deftest test-tag-add-multiple ()
  "Add multiple tags to an item at once."
  (let ((item (total-recall-make-item '(:term "Hallo" :definition "Hello"))))
    (total-recall-tag--add item :german :vocabulary :beginner)
    (should (= (length (funcall item 'get :tags)) 3))
    (should (member :german (funcall item 'get :tags)))
    (should (member :vocabulary (funcall item 'get :tags)))
    (should (member :beginner (funcall item 'get :tags)))))

(ert-deftest test-tag-add-duplicate-idempotent ()
  "Adding a duplicate tag is idempotent (no duplicates in list)."
  (let ((item (total-recall-make-item '(:term "Hallo" :definition "Hello"))))
    (total-recall-tag--add item :german)
    (total-recall-tag--add item :german)
    (should (equal (funcall item 'get :tags) '(:german)))))

(ert-deftest test-tag-add-mixed-new-and-duplicate ()
  "Adding a mix of new and duplicate tags only adds the new ones."
  (let ((item (total-recall-make-item '(:term "Hallo" :definition "Hello"))))
    (total-recall-tag--add item :german :vocabulary)
    (total-recall-tag--add item :german :beginner)
    (let ((tags (funcall item 'get :tags)))
      (should (member :german tags))
      (should (member :vocabulary tags))
      (should (member :beginner tags))
      (should (= (length tags) 3)))))

;; ---------------------------------------------------------------------------
;; 4.2 — total-recall-tag--remove
;; ---------------------------------------------------------------------------

(ert-deftest test-tag-remove-existing ()
  "Remove an existing tag from an item."
  (let ((item (total-recall-make-item '(:term "Hallo" :definition "Hello" :tags (:german :vocabulary)))))
    (total-recall-tag--remove item :german)
    (should (equal (funcall item 'get :tags) '(:vocabulary)))))

(ert-deftest test-tag-remove-non-existent ()
  "Removing a non-existent tag leaves tags unchanged."
  (let ((item (total-recall-make-item '(:term "Hallo" :definition "Hello" :tags (:german)))))
    (total-recall-tag--remove item :french)
    (should (equal (funcall item 'get :tags) '(:german)))))

(ert-deftest test-tag-remove-multiple ()
  "Remove multiple tags at once."
  (let ((item (total-recall-make-item '(:term "Hallo" :definition "Hello" :tags (:german :vocabulary :beginner)))))
    (total-recall-tag--remove item :german :beginner)
    (should (equal (funcall item 'get :tags) '(:vocabulary)))))

;; ---------------------------------------------------------------------------
;; 4.3 — total-recall-tag--list-all
;; ---------------------------------------------------------------------------

(ert-deftest test-tag-list-all-returns-distinct ()
  "List-all returns every distinct tag across items."
  (require 'total-recall-storage)
  (let* ((adapter (total-recall-storage-init nil))
         (item1 (total-recall-make-item '(:term "Hallo" :definition "Hello" :tags (:german :vocabulary))))
         (item2 (total-recall-make-item '(:term "Bonjour" :definition "Hello" :tags (:french :vocabulary)))))
    (funcall (plist-get adapter :save-item) item1)
    (funcall (plist-get adapter :save-item) item2)
    (let ((tags (total-recall-tag--list-all adapter)))
      (should (= (length tags) 3))
      (should (member :german tags))
      (should (member :french tags))
      (should (member :vocabulary tags)))))

(ert-deftest test-tag-list-all-collapses-duplicates ()
  "Duplicate tags across items are collapsed to one."
  (require 'total-recall-storage)
  (let* ((adapter (total-recall-storage-init nil))
         (item1 (total-recall-make-item '(:term "Hallo" :definition "Hello" :tags (:german))))
         (item2 (total-recall-make-item '(:term "Tschüss" :definition "Bye" :tags (:german)))))
    (funcall (plist-get adapter :save-item) item1)
    (funcall (plist-get adapter :save-item) item2)
    (let ((tags (total-recall-tag--list-all adapter)))
      (should (= (length tags) 1))
      (should (equal tags '(:german))))))

(ert-deftest test-tag-list-all-empty ()
  "List-all returns nil when no tags exist."
  (require 'total-recall-storage)
  (let* ((adapter (total-recall-storage-init nil))
         (item (total-recall-make-item '(:term "foo" :definition "bar"))))
    (funcall (plist-get adapter :save-item) item)
    (should (equal (total-recall-tag--list-all adapter) nil))))

(provide 'test-tags)
;;; test-tags.el ends here