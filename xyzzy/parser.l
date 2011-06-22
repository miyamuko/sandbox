; -*- mode: lisp-interaction -*-

(load "tokenizer.l")

(defvar *prev-token* nil)
(defvar *token* nil)
(defvar *eat-whitespace-or-comment-automatically* t)

(defun peek-token ()
  (car *token*))

(defun peek-token-type ()
  (token-type (peek-token)))

(defun peek-token-value ()
  (token-value (peek-token)))

(defun rest-tokens (&optional (n 3))
  (subseq *token* 0 (min n (length *token*))))

(defun end-of-line-p ()
  (eq (peek-token-type) :newline))

(defun has-more-token-p ()
  (not (not *token*)))

(defun token-type-p (type)
  (eq type (peek-token-type)))

(defun punc-p (value)
  (and (eq :punc (peek-token-type))
       (eq value (peek-token-value))))

(defun paren-p (value)
  (and (eq :paren (peek-token-type))
       (eq value (peek-token-value))))

(defun operator-p (value)
  (and (eq :operator (peek-token-type))
       (eq value (peek-token-value))))

(defun ident-p ()
  (eq :ident (peek-token-type)))


(defun error-unexpected-token (expected-type expected-value)
  (error "Unexpected token. expected '~A ~A', but was `~S'"
         expected-type expected-value
         (rest-tokens)))

(defun error-unknown-token ()
  (error "Unknown token '~S`" (rest-tokens)))

(defun get-token ()
  (prog1
      (car *token*)
    (setf *token* (cdr *token*))))

(defun eat-whitespace-or-comment (&key (eat-newline t))
  (let (skipped)
    (while *token*
      (case (peek-token-type)
        ((:comment :whitespace)
         ; do nothing
         )
        (:newline
         (unless eat-newline
           (return skipped)))
        (t
         (return skipped)))
      (push (get-token) skipped))
    skipped))

(defun uneat-token ()
  (while *prev-token*
    (push (pop *prev-token*) *token*)))

(defun safe-eat-token (&optional type value)
  (setf *prev-token* nil)
  (let ((token (peek-token)))
    (when (and (or (not type)
                   (eq type (token-type token)))
               (or (not value)
                   (equal value (token-value token))))
      (prog1
          (let ((r (get-token)))
            (push r *prev-token*)
            r)
        (when *eat-whitespace-or-comment-automatically*
          (dolist (skipped (eat-whitespace-or-comment :eat-newline t))
            (push skipped *prev-token*)))
        ))))

(defun eat-token (&optional type value)
  (or (safe-eat-token type value)
      (error-unexpected-token type value)))

(defun eat-token-value (&optional type value)
  (token-value (eat-token type value)))

(defun eat-ident (value)
  (eat-token :ident value))

(defun eat-punc (value)
  (eat-token :punc value))

(defun eat-paren (value)
  (eat-token :paren value))

(defun eat-operator (value)
  (eat-token :operator value))


(defun parse (c-src)
  (let ((*token* (tokenize-string c-src))
        ast)
    (while *token*
      (eat-whitespace-or-comment)
      (push (case (peek-token-type)
              (:directive (parse-directive))
              (:ident (parse-ident))
              (t (error-unknown-token)))
            ast))
    (nreverse ast)))


(defun parse-directive ()
  (case (peek-token-value)
    (:define (parse-directive-define))
    (t (error-unknown-token))))

(defun parse-directive-define ()
  (let ((*eat-whitespace-or-comment-automatically* nil))
    (eat-token :directive :define)
    (eat-whitespace-or-comment :eat-newline nil)
    (let ((name (eat-token-value :ident))
          value)
      (while (not (end-of-line-p))
        (eat-whitespace-or-comment :eat-newline nil)
        (push (eat-token-value) value))
      (list :define name (nreverse value)))))


(defun parse-ident ()
  (case (peek-token-value)
    (:typedef (parse-typedef))
    (t (parse-function-decl))))

(defun parse-function-decl ()
  (let (return-type name args)
    (setf return-type (parse-function-return-type))
    (setf name (eat-token-value :ident))
    (eat-paren #\()
    (setf args (parse-function-parameter-list))
    (eat-paren #\))
    (eat-punc #\;)
    (list return-type name args)))

(defun parse-function-return-type ()
  (prog1
      (butlast (parse-ident-list))
    (uneat-token)))

(defun parse-function-parameter-list ()
  (prog1
      (parse-separated-ident-list #\,)
    (when (token-type-p :vaarg)
      (let ((token (peek-token)))
        (error "Variable arguments not supported. (line ~D, column ~D)"
               (token-lineno token) (token-column token))
        ))))


(defun parse-typedef ()
  (eat-ident :typedef)
  (case (peek-token-value)
    (:struct
     (parse-typedef-struct))
    (:enum
     (parse-typedef-enum))
    (t
     (parse-typedef-simple))))

(defun parse-typedef-struct ()
  (eat-ident :struct)
  (parse-typedef-complex 'parse-typedef-struct-body))

(defun parse-typedef-struct-body ()
  (parse-separated-ident-list #\;))

(defun parse-typedef-enum ()
  (eat-ident :enum)
  (parse-typedef-complex 'parse-typedef-enum-body))

(defun parse-typedef-enum-body ()
  (let ((value 0)
        symbol body)
    (loop
      (setf symbol (eat-token-value :ident))
      (when (operator-p #\=)
        (eat-operator #\=)
        (setf value (eat-token-value)))
      (push (list symbol value) body)
      (when (paren-p #\})
        (return))
      (eat-punc #\,)
      (incf value))
    (nreverse body)))

(defun parse-typedef-complex (body-parser)
  (let (name body alias)
    (when (ident-p)
      (setf name (eat-token-value :ident)))
    (eat-paren #\{)
    (setf body (funcall body-parser))
    (eat-paren #\})
    (setf alias (parse-typedef-complex-alias))
    (eat-punc #\;)
    (list name body alias)
    ))

(defun parse-typedef-complex-alias ()
  (mapcar #'car (parse-separated-ident-list #\,)))

(defun parse-typedef-simple ()
  (let ((type-name (eat-token-value :ident))
        type-decl)
    (while (not (punc-p #\;))
      (push (eat-token-value :ident) type-decl))
    (eat-punc #\;)
    (list type-name (nreverse type-decl))
    ))

(defun parse-separated-ident-list (separator)
  (let (list)
    (while (and (has-more-token-p)
                (ident-p))
      (push (parse-ident-list) list)
      (if (and (has-more-token-p)
               (punc-p separator))
          (eat-punc separator)
        (return)))
    (nreverse list)))

(defun parse-ident-list ()
  (let (list)
    (while (and (has-more-token-p)
                (ident-p))
      (push (eat-token-value :ident) list))
    (nreverse list)))
