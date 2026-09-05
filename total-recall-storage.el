;;; total-recall-storage.el --- SQLite storage adapter  -*- lexical-binding: t; -*-

;;; Commentary: SQLite persistence layer.  `total-recall-storage-init'
;;; creates an in-memory (:memory:) or file-backed database, creates the
;;; three tables (items, schedule, related), and returns a plist of
;;; adapter functions.

;;; Code:

(require 'total-recall-item)
(require 'total-recall-sched)
(require 'cl-lib)

;; ---------------------------------------------------------------------------
;; Storage adapter factory
;; ---------------------------------------------------------------------------

(defun total-recall-storage-init (db-path)
  "Initialize storage at DB-PATH (nil for :memory:).

Returns a plist of adapter functions:
  :load-item      (fn id) → item-closure | nil
  :save-item      (fn item) → nil
  :delete-item    (fn id) → nil
  :load-schedule  (fn id) → schedule-closure | nil
  :save-schedule  (fn schedule) → nil
  :query-due      (fn) → list of item-closure
  :query-by-tag   (fn tag) → list of item-closure
  :list-all-tags  (fn) → list of symbols
  :query-all      (fn) → list of item-id"
  (let ((db (sqlite-open (if db-path db-path nil)))
        (db-path db-path))
    ;; Enable foreign keys for ON DELETE CASCADE
    (sqlite-execute db "PRAGMA foreign_keys = ON")
    ;; Create tables
    (sqlite-execute db "CREATE TABLE IF NOT EXISTS items (
      id         TEXT PRIMARY KEY,
      term       TEXT NOT NULL,
      definition TEXT NOT NULL,
      tags       TEXT NOT NULL DEFAULT '[]',
      depth      INTEGER NOT NULL DEFAULT 3,
      examples   TEXT NOT NULL DEFAULT '[]',
      analogy    TEXT DEFAULT NULL,
      notes      TEXT DEFAULT NULL,
      created    TEXT NOT NULL,
      modified   TEXT NOT NULL)")
    (sqlite-execute db "CREATE TABLE IF NOT EXISTS schedule (
      item_id     TEXT PRIMARY KEY REFERENCES items(id) ON DELETE CASCADE,
      interval    REAL NOT NULL DEFAULT 0,
      ease_factor REAL NOT NULL DEFAULT 2.5,
      repetitions INTEGER NOT NULL DEFAULT 0,
      next_review TEXT NOT NULL,
      last_review TEXT DEFAULT NULL,
      lapses      INTEGER NOT NULL DEFAULT 0)")
    (sqlite-execute db "CREATE TABLE IF NOT EXISTS related (
      item_id    TEXT NOT NULL REFERENCES items(id) ON DELETE CASCADE,
      related_id TEXT NOT NULL REFERENCES items(id) ON DELETE CASCADE,
      PRIMARY KEY (item_id, related_id))")
    ;; Adapter functions
    (list :load-item
          (lambda (id)
            "Load item by ID, returning an item closure or nil."
            (let ((rows (sqlite-select db
                          "SELECT id, term, definition, tags, depth, examples, analogy, notes, created, modified FROM items WHERE id = ?"
                          (list id))))
              (when-let ((row (car rows)))
                (pcase-let ((`(,db-id ,term ,definition ,tags ,depth ,examples ,analogy ,notes ,created ,modified) row))
                  (total-recall-make-item
                   (list :id db-id :term term :definition definition
                         :tags (mapcar #'intern (json-read-from-string tags))
                         :depth depth
                         :examples (and examples (append (json-read-from-string examples) nil))
                         :analogy analogy
                         :notes notes
                         :created created
                         :modified modified))))))

          :save-item
          (lambda (item)
            "Save ITEM (a closure) to DB via INSERT OR REPLACE."
            (let* ((data (funcall item 'serialize))
                   (tags (plist-get data :tags))
                   (encoded-tags (json-encode (if tags (mapcar #'symbol-name tags) [])))
                   (encoded-examples (json-encode (plist-get data :examples))))
              (sqlite-execute db
                "INSERT OR REPLACE INTO items (id, term, definition, tags, depth, examples, analogy, notes, created, modified) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
                (list (plist-get data :id)
                      (plist-get data :term)
                      (plist-get data :definition)
                      encoded-tags
                      (plist-get data :depth)
                      encoded-examples
                      (plist-get data :analogy)
                      (plist-get data :notes)
                      (plist-get data :created)
                      (plist-get data :modified)))))

          :delete-item
          (lambda (id)
            "Delete item by ID from the DB. CASCADE removes schedule and related records."
            (sqlite-execute db "DELETE FROM items WHERE id = ?" (list id)))
          :load-schedule
          (lambda (id)
            "Load schedule by item-id, returning a schedule closure or nil."
            (let ((rows (sqlite-select db
                          "SELECT item_id, interval, ease_factor, repetitions, next_review, last_review, lapses FROM schedule WHERE item_id = ?"
                          (list id))))
              (when-let ((row (car rows)))
                (pcase-let ((`(,db-item-id ,interval ,ease_factor ,repetitions ,next_review ,last_review ,lapses) row))
                  (total-recall-make-schedule
                   (list :item-id db-item-id :interval interval
                         :ease-factor ease_factor :repetitions repetitions
                         :next-review next_review
                         :last-review last_review
                         :lapses lapses))))))

          :save-schedule
          (lambda (schedule)
            "Save SCHEDULE (a closure) to DB via INSERT OR REPLACE."
            (let* ((data (funcall schedule 'serialize)))
              (sqlite-execute db
                "INSERT OR REPLACE INTO schedule (item_id, interval, ease_factor, repetitions, next_review, last_review, lapses) VALUES (?, ?, ?, ?, ?, ?, ?)"
                (list (plist-get data :item-id)
                      (plist-get data :interval)
                      (plist-get data :ease-factor)
                      (plist-get data :repetitions)
                      (plist-get data :next-review)
                      (plist-get data :last-review)
                      (plist-get data :lapses)))))
          :query-due (lambda () nil)
          :query-by-tag
          (lambda (tag)
            "Query items that have the given TAG (symbol)."
            (let ((rows (sqlite-select db
                          "SELECT DISTINCT items.id, items.term, items.definition, items.tags, items.depth, items.examples, items.analogy, items.notes, items.created, items.modified FROM items, json_each(items.tags) WHERE value = ?"
                          (list (symbol-name tag)))))
              (cl-loop for row in rows collect
                       (pcase-let ((`(,db-id ,term ,definition ,tags ,depth ,examples ,analogy ,notes ,created ,modified) row))
                         (total-recall-make-item
                          (list :id db-id :term term :definition definition
                                :tags (mapcar #'intern (json-read-from-string tags))
                                :depth depth
                                :examples (and examples (json-read-from-string examples))
                                :analogy analogy
                                :notes notes
                                :created created
                                :modified modified))))))
          :list-all-tags
          (lambda ()
            "Return every distinct tag symbol across all items."
            (let ((rows (sqlite-select db
                          "SELECT DISTINCT value FROM items, json_each(items.tags) ORDER BY value")))
              (cl-loop for row in rows collect
                       (intern (car row)))))
          :query-all (lambda () (mapcar #'car (sqlite-select db "SELECT id FROM items"))))))

(provide 'total-recall-storage)

;;; total-recall-storage.el ends here