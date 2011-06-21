; -*- mode: lisp-interaction -*-

(load "tokenizer.l")

(defvar *prev-token* nil)
(defvar *token* nil)
(defvar *ast* nil)
(defvar *eat-whitespace-or-comment-automatically* t)

(defun peek-token ()
  (unless *token*
    (error "No more token"))
  (car *token*))

(defun peek-token-type ()
  (token-type (peek-token)))

(defun peek-token-value ()
  (token-value (peek-token)))

(defun rest-tokens (&optional (n 3))
  (subseq *token* 0 (min n (length *token*))))

(defun end-of-line-p ()
  (eq (peek-token-type) :newline))

(defun end-of-file-p ()
  (not (peek-token-type)))

(defun punc-p (value)
  (and (eq :punc (peek-token-type))
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
      (setf *prev-token* (car *token*))
    (setf *token* (cdr *token*))))

(defun unget-token ()
  (when *prev-token*
    (push *prev-token* *token*)))

(defun eat-whitespace-or-comment1 (&key (eat-newline t))
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
      (get-token)
      (setf skipped t))
    skipped))

(defun eat-whitespace-or-comment (&key (eat-newline t))
  (let (skipped)
    (loop
      (unless (eat-whitespace-or-comment1 :eat-newline eat-newline)
        (return))
      (setf skipped t))
    skipped))

(defun safe-eat-token (&optional type value)
  (let ((token (peek-token)))
    (when (and (or (not type)
                   (eq type (token-type token)))
               (or (not value)
                   (equal value (token-value token))))
      (prog1
          (get-token)
        (when *eat-whitespace-or-comment-automatically*
          (eat-whitespace-or-comment))
        ))))

(defun eat-token (&optional type value)
  (or (safe-eat-token type value)
      (error-unexpected-token type value)))

(defun eat-ident (value)
  (eat-token :ident value))


(defun parse (c-src)
  (let ((*token* (tokenize-string c-src))
        (*ast* nil))
    (while *token*
      (eat-whitespace-or-comment)
      (case (peek-token-type)
        (:directive (parse-directive))
        (:ident (parse-ident))
        (t (error-unknown-token))))
    (nreverse *ast*)))


(defun parse-directive ()
  (case (peek-token-value)
    (:define (parse-directive-define))
    (t (error-unknown-token))))

(defun parse-directive-define ()
  (let ((*eat-whitespace-or-comment-automatically* nil))
    (eat-token :directive :define)
    (eat-whitespace-or-comment :eat-newline nil)
    (let ((name (token-value (eat-token :ident)))
          value)
      (while (not (end-of-line-p))
        (eat-whitespace-or-comment :eat-newline nil)
        (push (token-value (eat-token)) value))
      (push (list :define name (nreverse value)) *ast*))))


(defun parse-ident ()
  (case (peek-token-value)
    (:typedef (parse-ident-typedef))
    (t (parse-function-decl))))

(defun parse-function-decl ()
  (parse-function-return)
  )

(defun parse-function-return ()
  (parse-list :end #'(lambda ()
                       (eat-whitespace-or-comment)
                       (when (punc-p #\()
                         (unget-token)
                         t))
              :parser #'(lambda ()
                          (token-value (eat-token :ident)))
              :separator nil
              ))
(let ((*token* (tokenize-string "int long Foo()")))
  (parse-ident))

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
  (parse-list :end #'(lambda ()
                       (punc-p #\}))
              :parser #'(lambda ()
                          (list (token-value (eat-token :ident))
                                (token-value (eat-token :ident))))
              :separator #\;
              ))

(defun parse-typedef-enum ()
  (eat-ident :enum)
  (parse-typedef-complex 'parse-typedef-enum-body))

(defun parse-typedef-enum-body ()
  (let ((value 0)
        symbol body)
    (loop
      (setf symbol (token-value (eat-token :ident)))
      (when (punc-p #\=)
        (eat-token :punc #\=)
        (setf value (token-value (eat-token))))
      (push (list symbol value) body)
      (when (punc-p #\})
        (return))
      (eat-token :punc #\,)
      (incf value))
    (nreverse body)))

(defun parse-typedef-complex (body-parser)
  (let (name body alias)
    (when (ident-p)
      (setf name (token-value (eat-token :ident))))
    (eat-token :punc #\{)
    (setf body (funcall body-parser))
    (eat-token :punc #\})
    (setf alias (parse-typedef-complex-alias))
    (eat-token :punc #\;)
    (push (list name body alias)
          *ast*)
    ))

(defun parse-typedef-complex-alias ()
  (parse-list :end #'(lambda ()
                       (punc-p #\;))
              :parser #'(lambda ()
                          (token-value (eat-token :ident)))
              :separator #\,
              ))

(defun parse-typedef-simple ()
  (let ((type-name (token-value (eat-token :ident)))
        type-decl)
    (while (not (punc-p #\;))
      (push (token-value (eat-token :ident)) type-decl))
    (eat-token :punc #\;)
    (push (list type-name (nreverse type-decl))
          *ast*)))

(defun parse-list (&key end parser separator)
  (let (list)
    (while (not (funcall end))
      (push (funcall parser) list)
      (when separator
        (if (punc-p separator)
            (eat-token :punc separator)
          (return))))
    (nreverse list)))
