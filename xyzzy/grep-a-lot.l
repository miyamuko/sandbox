(defvar *grep-a-lot-buffer-format* "*grep*<~A>")
(defvar *grep-a-lot-abbrev-length* 20)

(defun grep-a-lot ()
  (rename-grep-buffer))

(defun grepd-a-lot ()
  (rename-grep-buffer))

(defun rename-grep-buffer ()
  (rename-buffer (grep-a-lot-buffer-name)))

(defun grep-a-lot-buffer-name ()
  (format nil *grep-a-lot-buffer-format*
          (abbreviate-display-string (grep-a-lot-pattern) *grep-a-lot-abbrev-length*)))

(defun grep-a-lot-pattern ()
  ;; 検索文字列を頑張って取得する。
  ;; *last-grep-regexp* や *last-fgrep-regexp* や *minibuffer-search-string-history*
  ;; を見る方法もあるが、ed::scan-files を直接呼んだ場合は取得できない。
  ;; そこで、ed::*find-error-scanner* というバッファローカル変数に入っている
  ;; scanner というクロージャが束縛している pattern 変数から取り出す。
  (let* ((vars (si:closure-variable ed::*find-error-scanner*))
         (pattern (cdr (assoc 'ed::pattern vars))))
    (cond ((typep pattern 'regexp)
           (compiled-regexp-source pattern))
          ((stringp pattern)
           pattern)
          (t
           "???"))))

(defun list-grep-a-lot-buffers ()
  (let ((regexp (format nil (regexp-quote *grep-a-lot-buffer-format*) ".*")))
    (remove-if-not #'(lambda (b)
                       (string-matchp regexp (buffer-name b)))
                   (buffer-list))))

(defun kill-grep-a-lot-buffers ()
  (interactive)
  (mapc 'kill-buffer (list-grep-a-lot-buffers)))

(add-hook '*grep-hook* 'grep-a-lot)
(add-hook '*grepd-hook* 'grepd-a-lot)
