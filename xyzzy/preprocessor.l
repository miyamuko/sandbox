(defparameter *c-ignore-ident-list*
  (list "IN" "OUT" "OPTIONAL"))

(defun preprocess (token)
  (let ((*token* token))
    (filter-continued-line)
    (filter-specstrings)
    *token*))

(defun filter-continued-line ()
  (setf *token*
        (remove-token *token* '((:punc #\\)
                                (:newline nil)))))

(defun filter-specstrings ()
  (let (r skip (nest 0))
    (while *token*
      (when skip
        (cond ((punc-p #\() (incf nest))
              ((punc-p #\)) (decf nest))
              (t (setf skip (not (zerop nest))))))
      (unless skip
        (let ((value (peek-token-value)))
          (when (and (ident-p) (symbolp value)
                     (or (string-match "^__" (string (peek-token-value)))
                         (member value *c-ignore-ident-list* :test #'string=)))
            (setf skip t))))
      (let ((token (get-token)))
        (unless skip
          (push token r))))
    (setf *token* (nreverse r))))

(defun remove-token (token replacement)
  (remove-list token replacement
               :test #'(lambda (token pattern)
                         (let ((type (car pattern))
                               (value (cadr pattern)))
                           (and (eq (token-type token) type)
                                (or (not value)
                                    (eq (token-value token) value)))
                           ))))

(defun remove-list (list pattern &key test)
  (replace-list list pattern nil :test test))

(defun replace-list (list pattern replacement &key test)
  (let ((pattern-length (length pattern))
        r)
    (while list
      (cond ((and (<= pattern-length (length list))
                  (every test list pattern))
             (dolist (e replacement)
               (push e r))
             (setf list (subseq list pattern-length)))
            (t
             (push (car list) r)
             (setf list (cdr list)))))
    (nreverse r)))
