## 1. Entry Point File

- [x] 1.1 Create `total-recall.el` that provides the `total-recall` feature and loads sub-modules in correct dependency order (item, tags, sched, storage, capture). Verify by loading the file in Emacs (`emacs --batch --eval "(load-file \"total-recall.el\")"`) and confirming that `(featurep 'total-recall)` returns `t`.
- [x] 1.2 Verify package installability by simulating a `use-package` load with `:straight` using the `:local-repo` option pointing to this checkout, confirming no load errors.