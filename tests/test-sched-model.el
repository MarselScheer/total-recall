;;; test-sched-model.el --- Tests for total-recall-sched  -*- lexical-binding: t; -*-

(require 'ert)
(require 'total-recall-sched)

(ert-deftest test-schedule-new-has-defaults ()
  "New schedule has correct default values.
SC-2026-09-09_18-29-07-01, SC-2026-09-09_18-29-07-03, SC-2026-09-09_18-29-07-04"
  (let ((sched (total-recall-make-schedule '(:item-id "abc-123"))))
    (should (equal (funcall sched 'get :item-id) "abc-123"))
    (should (equal (funcall sched 'get :direction) "forward"))
    (should (equal (funcall sched 'get :interval) 0.0))
    (should (equal (funcall sched 'get :ease-factor) 2.5))
    (should (equal (funcall sched 'get :repetitions) 0))
    (should (equal (funcall sched 'get :lapses) 0))
    (should (stringp (funcall sched 'get :next-review)))))

(ert-deftest test-schedule-direction-backward ()
  "Backward direction is accepted.
SC-2026-09-09_18-29-07-02"
  (let ((sched (total-recall-make-schedule '(:item-id "abc-123" :direction "backward"))))
    (should (equal (funcall sched 'get :direction) "backward"))))

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

;; ---------------------------------------------------------------------------
;; SM-2 grading (total-recall-sched--sm2-grade)
;; ---------------------------------------------------------------------------

(ert-deftest test-sm2-grade-correct-first-review ()
  "Correct first review advances repetitions to 1, interval to 1.0, EF to 2.6.
SC-2026-09-09_18-29-07-07"
  (let* ((sched (total-recall-make-schedule '(:item-id "abc-123")))
         (result (total-recall-sched--sm2-grade 5 sched)))
    (should (equal (plist-get result :repetitions) 1))
    (should (equal (plist-get result :interval) 1.0))
    (should (equal (plist-get result :ease-factor) 2.6))))

(ert-deftest test-sm2-grade-correct-second-review ()
  "Correct second review sets interval to 6.0.
SC-2026-09-09_18-29-07-08"
  (let* ((sched (total-recall-make-schedule
                 '(:item-id "abc-123" :repetitions 1 :interval 1.0 :ease-factor 2.6)))
         (result (total-recall-sched--sm2-grade 5 sched)))
    (should (equal (plist-get result :repetitions) 2))
    (should (equal (plist-get result :interval) 6.0))))

(ert-deftest test-sm2-grade-correct-subsequent-review ()
  "Correct subsequent reviews multiply interval by ease-factor.
SC-2026-09-09_18-29-07-09"
  (let* ((sched (total-recall-make-schedule
                 '(:item-id "abc-123" :repetitions 2 :interval 6.0 :ease-factor 2.5)))
         (result (total-recall-sched--sm2-grade 5 sched)))
    (should (equal (plist-get result :repetitions) 3))
    (should (equal (plist-get result :interval) 15.0))))

(ert-deftest test-sm2-grade-wrong-resets-schedule ()
  "Wrong answer resets repetitions/interval, increments lapses, decreases EF.
SC-2026-09-09_18-29-07-10"
  (let* ((sched (total-recall-make-schedule
                 '(:item-id "abc-123" :repetitions 5 :interval 30.0 :ease-factor 2.5 :lapses 0)))
         (result (total-recall-sched--sm2-grade 0 sched)))
    (should (equal (plist-get result :repetitions) 0))
    (should (equal (plist-get result :interval) 0.0))
    (should (equal (plist-get result :lapses) 1))
    (should (equal (plist-get result :ease-factor) 1.7))))

(ert-deftest test-sm2-grade-ease-factor-floor ()
  "Ease factor is clamped to a minimum of 1.3.
SC-2026-09-09_18-29-07-11"
  (let* ((sched (total-recall-make-schedule
                 '(:item-id "abc-123" :ease-factor 1.5)))
         (result (total-recall-sched--sm2-grade 0 sched)))
    ;; Raw SM-2 formula: 1.5 - 0.8 = 0.7, clamped to 1.3
    (should (equal (plist-get result :ease-factor) 1.3))))

(ert-deftest test-sm2-grade-updates-last-and-next-review ()
  "Grading updates :last-review and :next-review timestamps.
SC-2026-09-09_18-29-07-12"
  (let* ((now (encode-time 0 0 12 1 1 2026))
         (fmt "%Y-%m-%dT%H:%M:%S.%6N%z")
         (sched (total-recall-make-schedule '(:item-id "abc-123")))
         (result (total-recall-sched--sm2-grade 5 sched (lambda () now))))
    (should (equal (plist-get result :last-review)
                   (format-time-string fmt now)))
    ;; Quality 5 on first review → interval 1.0 → now + 1 day
    (should (equal (plist-get result :next-review)
                   (format-time-string fmt
                                       (time-add now (days-to-time 1.0))))))

  (let* ((now (encode-time 0 0 12 1 1 2026))
         (fmt "%Y-%m-%dT%H:%M:%S.%6N%z")
         (sched (total-recall-make-schedule
                 '(:item-id "abc-123" :repetitions 2 :interval 6.0 :ease-factor 2.5)))
         (result (total-recall-sched--sm2-grade 5 sched (lambda () now))))
    ;; Quality 5 on subsequent review → interval 6.0 * 2.5 = 15.0 → now + 15 days
    (should (equal (plist-get result :next-review)
                   (format-time-string fmt
                                       (time-add now (days-to-time 15.0)))))))

(provide 'test-sched-model)
;;; test-sched-model.el ends here