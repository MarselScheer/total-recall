;;; test-item-model.el --- Tests for total-recall-item  -*- lexical-binding: t; -*-

(require 'ert)
(require 'json)
(require 'total-recall-item)

(ert-deftest test-item-new-item-has-all-required-fields ()
  "New item with term and definition has all required fields with defaults."
  (let ((item (total-recall-make-item '(:term "voracious" :definition "eating or drinking large amounts"))))
    (should (stringp (funcall item 'get :id)))
    (should (equal (funcall item 'get :term) "voracious"))
    (should (equal (funcall item 'get :definition) "eating or drinking large amounts"))
    (should (equal (funcall item 'get :tags) nil))
    (should (equal (funcall item 'get :depth) 3))
    (should (stringp (funcall item 'get :created)))
    (should (equal (funcall item 'get :created) (funcall item 'get :modified)))))

(ert-deftest test-item-create-with-optional-fields ()
  "Item with term, definition, and optional fields has those optional fields."
  (let ((item (total-recall-make-item
               '(:term "dependency injection"
                 :definition "passing dependencies as arguments"
                 :examples (("In Python" . (:lang "Python"))
                            ("In Elisp" . (:lang "Elisp")))))))
    (should (funcall item 'get :term))
    (should (equal (funcall item 'get :examples)
                   '(("In Python" . (:lang "Python"))
                     ("In Elisp" . (:lang "Elisp")))))))

(ert-deftest test-item-get-existing-key ()
  "Get returns the value for an existing key."
  (let ((item (total-recall-make-item '(:term "voracious" :definition "eating large amounts"))))
    (should (equal (funcall item 'get :term) "voracious"))))

(ert-deftest test-item-get-missing-key ()
  "Get returns nil for a missing key."
  (let ((item (total-recall-make-item '(:term "voracious" :definition "eating large amounts"))))
    (should (equal (funcall item 'get :nonexistent) nil))))

(ert-deftest test-item-set-existing-key ()
  "Set updates an existing key and updates modified timestamp."
  (let ((item (total-recall-make-item '(:term "voracious" :definition "eating large amounts")))
        (original-modified))
    (setq original-modified (funcall item 'get :modified))
    (funcall item 'set :definition "new definition")
    (should (equal (funcall item 'get :definition) "new definition"))
    (should (not (equal (funcall item 'get :modified) original-modified)))))

(ert-deftest test-item-set-new-key ()
  "Set adds a new key to the item."
  (let ((item (total-recall-make-item '(:term "voracious" :definition "eating large amounts"))))
    (funcall item 'set :notes "some notes")
    (should (equal (funcall item 'get :notes) "some notes"))))

(ert-deftest test-item-serialize-returns-plist ()
  "Serialize returns the internal plist."
  (let* ((item (total-recall-make-item '(:term "voracious" :definition "eating large amounts")))
         (plist (funcall item 'serialize)))
    (should (listp plist))
    (should (plist-get plist :term))
    (should (equal (plist-get plist :term) "voracious"))))

(ert-deftest test-item-serialize-round-trips-directly ()
  "The serialized plist can be fed directly to make-item for a round-trip."
  (let* ((original (total-recall-make-item
                     '(:term "voracious"
                       :definition "eating large amounts")))
         (serialized (funcall original 'serialize))
         (restored (total-recall-make-item serialized)))
    (should (equal (funcall original 'get :term) (funcall restored 'get :term)))
    (should (equal (funcall original 'get :definition) (funcall restored 'get :definition)))
    (should (equal (funcall original 'get :depth) (funcall restored 'get :depth)))))

(ert-deftest test-item-serialize-is-json-encodable ()
  "The serialized plist can be json-encoded without errors."
  (let* ((item (total-recall-make-item '(:term "voracious" :definition "eating large amounts")))
         (json-string (json-encode (funcall item 'serialize))))
    (should (stringp json-string))
    (should (> (length json-string) 0))
    (should (string-match-p "voracious" json-string))))

;; ---------------------------------------------------------------------------
;; Validation — missing mandatory keys
;; ---------------------------------------------------------------------------

(ert-deftest test-item-missing-term-signals-error ()
  "make-item signals an error when :term is missing."
  (should-error (total-recall-make-item '(:definition "eating large amounts"))
                :type 'error))

(ert-deftest test-item-missing-definition-signals-error ()
  "make-item signals an error when :definition is missing."
  (should-error (total-recall-make-item '(:term "voracious"))
                :type 'error))

(ert-deftest test-item-missing-term-and-definition-signals-error ()
  "make-item signals an error when both :term and :definition are missing."
  (should-error (total-recall-make-item '(:tags (:vocabulary)))
                :type 'error))

(ert-deftest test-item-valid-input-still-works ()
  "Regression: valid input with both :term and :definition still creates an item."
  (should (functionp (total-recall-make-item '(:term "voracious" :definition "eating large amounts")))))

(provide 'test-item-model)
;;; test-item-model.el ends here