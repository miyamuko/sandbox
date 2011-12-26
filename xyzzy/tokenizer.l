;; (tokenize "typedef unsigned long ULONG, *ULONG_PTR, ** ULONG_PTR_PTR")
;; (tokenize "C:/Program Files/Microsoft SDKs/Windows/v6.0A/Include/winhttp.h" :file t)

(defparameter *c-keyword-list*
  (list "typedef" "enum" "struct" "union" "const" "extern"))

(defparameter *c-operator-list*
  (list "=" "*=" "/=" "%=" "+=" "-=" "<<=" ">>=" "&=" "^=" "|="
        "||" "&&" "|" "&" "~"
        "==" "!="
        "<" ">" "<=" ">="
        "<<" ">>"
        "+" "-" "*" "/" "%"
        "++" "--" "sizeof"
        "." "->" "++" "--"))

(defparameter *c-operator-list-regexp*
  (format nil "\\(~{~A~^\\|~}\\)"
          (mapcar 'regexp-quote *c-operator-list*)))


(defun make-token (lineno column type value)
  (list lineno column type value))

(defun token-lineno (token) (nth 0 token))
(defun token-column (token) (nth 1 token))
(defun token-type (token)   (nth 2 token))
(defun token-value (token)  (nth 3 token))


(defun tokenize-string (string &key ignore)
  (tokenize string :ignore ignore))

(defun tokenize-file (file &key ignore)
  (tokenize file :file t :ignore ignore))

(defun tokenize (string-or-file &key file ignore)
  (let ((b (get-buffer-create "*temp*")))
    (unwind-protect
        (progn
          (set-buffer b)
          (if file
              (insert-file-contents string-or-file)
            (insert string-or-file))
          (goto-char (point-min))
          (let (r token)
            (loop
              (let ((token (scan-next-token)))
                (unless token
                  (return))
                (unless (member (token-type token) ignore)
                  (push token r))))
            (nreverse r)))
      (delete-buffer b))))

(defun scan-next-token ()
  (multiple-value-bind (type token)
      (scan-next-token1)
    (when token
      (make-token (current-line-number) (current-column)
                  type token))))

(defun scan-next-token1 ()
  (let ((opoint (point)))
    (flet ((substr ()
             (buffer-substring opoint (point)))
           (forward-matched ()
             (forward-char (length (match-string 0))))
           (looking-number (radix)
             (funcall (if (eq (match-string 1) "-") '- '+)
                      (parse-integer (match-string 2) :radix radix)))
           (current-char ()
             (forward-char)
             (char-before (point)))
           (keyword (str)
             (intern str :keyword))
           )
      (cond ((eobp)
             (values nil nil))
            ((skip-chars-forward " \t")
             (values :whitespace (substr)))
            ((skip-chars-forward "\n")
             (values :newline (substr)))
            ((looking-for "//")
             (goto-eol)
             (values :comment (substr)))
            ((looking-for "/*")
             (unless (scan-buffer "*/" :tail t)
               (error "unterminated comment (*/ not found)"))
             (values :comment (substr)))
            ((looking-at "#[ \t]*\\([a-z]+\\)")
             (forward-matched)
             (values :directive (keyword (match-string 1))))
            ((looking-at "\\(\\*+\\)?[ \t]*\\([a-zA-Z_][a-zA-Z0-9_]*\\)")
             (forward-matched)
             (let* ((ptr (match-string 1))
                    (ident (match-string 2))
                    (sym (if (member ident *c-keyword-list* :test #'string=)
                             (keyword ident)
                           (intern ident))))
                 (values :ident (if ptr (list (intern ptr) sym) sym))))
            ((looking-at "\\([+-]?[0-9]*\\.[0-9]\\([eE][0-9]+\\)?\\)[FDfd]*")
             (forward-matched)
             (values :number (read-from-string (match-string 1))))
            ((looking-at "\\([+-]?\\)0x\\([0-9a-fA-F]+\\)[ULul]*")
             (forward-matched)
             (values :number (looking-number 16)))
            ((looking-at "\\([+-]?\\)0\\([0-9]+\\)[ULul]*")
             (forward-matched)
             (values :number (looking-number 8)))
            ((looking-at "\\([+-]?\\)\\([1-9][0-9]*\\)[ULul]*")
             (forward-matched)
             (values :number (looking-number 10)))
            ((looking-at "N?\"\\(.*?\\)\"")
             (forward-matched)
             (values :string (match-string 1)))
            ((looking-at "<\\(.*?\\)>")
             (forward-matched)
             (values :include (match-string 1)))
            ((looking-for "...")
             (forward-char 3)
             (values :vaarg (substr)))
            ((looking-at *c-operator-list-regexp*)
             (forward-matched)
             (values :operator (keyword (substr))))
            (t
             (values :punc (current-char)))
            ))))
