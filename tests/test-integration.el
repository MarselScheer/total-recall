;;; test-integration.el --- Integration test for total-recall data pipeline  -*- lexical-binding: t; -*-

(require 'ert)
(require 'total-recall-item)
(require 'total-recall-sched)
(require 'total-recall-storage)
(require 'total-recall-tags)

(ert-deftest test-full-pipeline-create-tag-save-load ()
  "Full pipeline: create item via factory, tag it, save to SQLite,
load it back, and assert all data is preserved."
  (let* ((adapter (total-recall-storage-init nil))
         (item (total-recall-make-item
                '(:term "dependency injection"
                  :definition "passing dependencies as function arguments"
                  :examples ("In Python: injection via args"
                             "In Elisp: closure over deps")
                  :analogy "Like ordering food at a restaurant"
                  :notes "Core concept in software design")))
         (id (funcall item 'get :id))
         (original-data (funcall item 'serialize)))

    ;; Tag the item
    (total-recall-tag--add item :software :design-patterns)
    (let ((tagged-data (funcall item 'serialize)))
      (should (member :software (plist-get tagged-data :tags)))
      (should (member :design-patterns (plist-get tagged-data :tags))))

    ;; Save to SQLite
    (funcall (plist-get adapter :save-item) item)

    ;; Create and save a schedule record
    (let ((sched (total-recall-make-schedule
                  (list :item-id id :interval 0.0))))
      (funcall (plist-get adapter :save-schedule) sched))

    ;; Load back from SQLite
    (let* ((loaded (funcall (plist-get adapter :load-item) id))
           (loaded-data (funcall loaded 'serialize)))

      ;; Verify all fields preserved
      (should loaded)
      (should (equal (plist-get loaded-data :term)
                     (plist-get original-data :term)))
      (should (equal (plist-get loaded-data :definition)
                     (plist-get original-data :definition)))
      (should (equal (plist-get loaded-data :examples)
                     (plist-get original-data :examples)))
      (should (equal (plist-get loaded-data :analogy)
                     (plist-get original-data :analogy)))
      (should (equal (plist-get loaded-data :notes)
                     (plist-get original-data :notes)))
      ;; Tags should include the added ones
      (should (member :software (plist-get loaded-data :tags)))
      (should (member :design-patterns (plist-get loaded-data :tags)))
      (should (equal (plist-get loaded-data :depth)
                     (plist-get original-data :depth)))
      (should (equal (plist-get loaded-data :created)
                     (plist-get original-data :created)))
      (should (equal (plist-get loaded-data :modified)
                     (plist-get original-data :modified))))

    ;; Verify schedule loaded back
    (let ((loaded-sched (funcall (plist-get adapter :load-schedule) id)))
      (should loaded-sched)
      (should (equal (funcall loaded-sched 'get :item-id) id)))))

(provide 'test-integration)
;;; test-integration.el ends here