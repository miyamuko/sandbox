(defvar *grep-a-lot-buffer-format* "*grep*<~A>")
(defvar *grep-a-lot-abbrev-length* 20)

(defparameter *grep-a-lot-last-context* nil)


(defun grep-a-lot-setup-keys ()
  (define-key esc-map '(#\g #\]) 'grep-a-lot-goto-next)
  (define-key esc-map '(#\g #\[) 'grep-a-lot-goto-prev)
  (define-key esc-map '(#\g #\-) 'grep-a-lot-pop-stack)
  (define-key esc-map '(#\g #\_) 'grep-a-lot-clear-stack)
  (define-key esc-map '(#\g #\=) 'grep-a-lot-restart-context))

(defun grep-a-lot-restart-context ()
  "現在の grep バッファを開く"
  (interactive)
  (let* ((b (grep-a-lot-last-context))
         (w (get-buffer-window b)))
    (if w
        (set-window w)
      (set-buffer b))))

(defun grep-a-lot-pop-stack ()
  "現在の grep バッファを削除する"
  (interactive)
  (let ((current (selected-buffer)))
    (when (grep-a-lot-buffer-p current)
      (grep-a-lot-goto-next)
      (kill-buffer current))))

(defun grep-a-lot-clear-stack ()
  "全 grep バッファを削除する"
  (interactive)
  (mapc 'kill-buffer (list-grep-a-lot-buffers)))

(defun grep-a-lot-goto-next ()
  "次の grep バッファを開く"
  (interactive)
  (grep-a-lot-goto :reverse nil))

(defun grep-a-lot-goto-prev ()
  "前の grep バッファを開く"
  (interactive)
  (grep-a-lot-goto :reverse t))


(defun grep-a-lot-last-context ()
  (if (and *grep-a-lot-last-context*
           (not (deleted-buffer-p *grep-a-lot-last-context*)))
      *grep-a-lot-last-context*
    (last-grep-a-lot-buffer)))

(defun grep-a-lot-goto (&key reverse (buffer-bar-order *next-buffer-in-tab-order*))
  (let ((next (get-next-grep-a-lot-buffer
               :reverse reverse
               :buffer-bar-order buffer-bar-order)))
    (when next
      (set-buffer next))))

(defun get-next-grep-a-lot-buffer (&key reverse
                                        (buffer-bar-order *next-buffer-in-tab-order*))
  (let* ((obuffer (selected-buffer))
         (current obuffer))
    (loop
      (let ((next (get-next-buffer current reverse buffer-bar-order)))
        (when (equal obuffer next)
          (return nil))
        (when (grep-a-lot-buffer-p next)
          (return next))
        (setf current next)))))

(defun list-grep-a-lot-buffers (&key buffer-bar-order)
  (remove-if-not #'grep-a-lot-buffer-p
                 (buffer-list :buffer-bar-order buffer-bar-order)))

(defun last-grep-a-lot-buffer ()
  (car (last (list-grep-a-lot-buffers :buffer-bar-order t))))

(defun grep-a-lot-buffer-p (buffer)
  (let ((regexp (format nil (regexp-quote *grep-a-lot-buffer-format*) ".*")))
    (string-matchp regexp (buffer-name buffer))))

(defun grep-a-lot-buffer-name ()
  (format nil *grep-a-lot-buffer-format*
          (abbreviate-display-string (grep-a-lot-pattern) *grep-a-lot-abbrev-length*)))

(defun grep-a-lot-pattern ()
  ;; 検索文字列を頑張って取得する。
  ;; *last-grep-regexp* や *last-fgrep-regexp* や *minibuffer-search-string-history*
  ;; を見る方法もあるが、ed::scan-files を直接呼んだ場合は取得できない。
  ;; そこで、ed::*find-error-scanner* というバッファローカル変数に入っている
  ;; クロージャが束縛している pattern 変数から取り出す。
  (let* ((vars (si:closure-variable ed::*find-error-scanner*))
         (pattern (cdr (assoc 'ed::pattern vars))))
    (cond ((typep pattern 'regexp)
           (compiled-regexp-source pattern))
          ((stringp pattern)
           pattern)
          (t
           "???"))))


(defun rename-grep-buffer-hook ()
  (rename-buffer (grep-a-lot-buffer-name)))

(defun grep-a-lot-first-error-hook ()
  (when (equal *this-command* 'first-error)
    (setf *grep-a-lot-last-context* (selected-buffer))))

(add-hook '*grep-hook* 'rename-grep-buffer-hook)
(add-hook '*grepd-hook* 'rename-grep-buffer-hook)
(add-hook '*pre-command-hook* 'grep-a-lot-first-error-hook)
