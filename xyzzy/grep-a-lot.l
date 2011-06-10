(defvar *grep-a-lot-buffer-format* "*grep*<~A>")
(defvar *grep-a-lot-abbrev-length* 20)

(defun grep-a-lot ()
  (rename-grep-buffer *last-grep-regexp*))

(defun grepd-a-lot ()
  (rename-grep-buffer (car *minibuffer-search-string-history*)))

(defun rename-grep-buffer (regexp)
  (rename-buffer (grep-a-lot-buffer-name regexp)))

(defun grep-a-lot-buffer-name (regexp)
  (format nil *grep-a-lot-buffer-format*
          (abbreviate-display-string regexp *grep-a-lot-abbrev-length*)))

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
