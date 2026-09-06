;;; test-sched-model.el --- Tests for total-recall-sched  -*- lexical-binding: t; -*-

(require 'ert)
(require 'total-recall-sched)

(ert-deftest test-schedule-new-has-defaults ()
  "New schedule has correct default values."
  (let ((sched (total-recall-make-schedule '(:item-id "abc-123"))))
    (should (equal (funcall sched 'get :item-id) "abc-123"))
    (should (equal (funcall sched 'get :interval) 0.0))
    (should (equal (funcall sched 'get :ease-factor) 2.5))
    (should (equal (funcall sched 'get :repetitions) 0))
    (should (equal (funcall sched 'get :lapses) 0))
    (should (stringp (funcall sched 'get :next-review)))))

(ert-deftest test-schedule-get-set ()
  "Schedule supports get and set dispatch."
  (let ((sched (total-recall-make-schedule '(:item-id "abc-123"))))
    (should (= (funcall sched 'get :interval) 0.0))
    (funcall sched 'set :repetitions 3)
    (should (= (funcall sched 'get :repetitions) 3))
    (funcall sched 'set :interval 1.5)
    (should (= (funcall sched 'get :interval) 1.5))))

(ert-deftest test-schedule-serialize ()
  "Serialize returns schedule plist."
  (let ((sched (total-recall-make-schedule '(:item-id "abc-123" :interval 2.0))))
    (let ((plist (funcall sched 'serialize)))
      (should (listp plist))
      (should (equal (plist-get plist :item-id) "abc-123"))
      (should (equal (plist-get plist :interval) 2.0)))))

(provide 'test-sched-model)
;;; test-sched-model.el ends here