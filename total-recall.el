;;; total-recall.el --- Spaced-repetition memorization system  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Marsel Scheer

;; Author: Marsel Scheer
;; URL: https://github.com/MarselScheer/total-recall
;; Version: 0.1.0
;; Package-Requires: ((emacs "26.1"))
;; Keywords: convenience, memory, tools

;; This file is not part of GNU Emacs.

;;; Commentary: Entry point for the Total Recall memorization system.
;;; Loads all sub-modules in the correct dependency order:
;;;   item -> tags -> sched -> storage -> capture

;;; Code:

(require 'total-recall-item)
(require 'total-recall-tags)
(require 'total-recall-sched)
(require 'total-recall-storage)
(require 'total-recall-capture)

(provide 'total-recall)

;;; total-recall.el ends here
