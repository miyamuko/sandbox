(load "tokenizer.l")
(load "preprocessor.l")

(defvar *prev-token* nil)
(defvar *token* nil)
(defvar *eat-whitespace-or-comment-automatically* t)

(defstruct c-type
  type decl)

(defstruct c-struct
  name members)

(defstruct c-enum
  name members)

(defstruct c-func
  name return-type args)

(defstruct c-callback
  type return-type args)

(defstruct c-macro
  name value)

(defstruct c-if
  condition body else)


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

(defun eat-tokens-of-line ()
  (let ((*eat-whitespace-or-comment-automatically* nil)
        r)
    (while (and (has-more-token-p)
                (not (end-of-line-p)))
      (case (peek-token-type)
        ((:comment :whitespace)
         (eat-whitespace-or-comment :eat-newline nil))
        (t
         (push (eat-token-value) r))))
    (eat-whitespace-or-comment :eat-newline t)
    (nreverse r)))

(defun eat-ident (value)
  (eat-token :ident value))

(defun eat-directive (value)
  (eat-token :directive value))

(defun eat-punc (value)
  (eat-token :punc value))

(defun eat-operator (value)
  (eat-token :operator value))


(defun parse-file (c-header-file)
  (parse-token (tokenize-file c-header-file :ignore '(:whitespace :comment))))

(defun parse-string (c-header-string)
  (parse-token (tokenize-string c-header-string :ignore '(:whitespace :comment))))

(defun parse-token (token)
  (let ((*token* (preprocess token)))
    (parse)))

(defun parse ()
  (prog1
      (try-parse)
    (when *token*
      (error-unknown-token))))

(defun try-parse ()
  (let ((ast nil)
        (*stop-parse* nil))
    (declare (special *stop-parse*))
    (while (and *token* (not *stop-parse*))
      (eat-whitespace-or-comment)
      (let ((defs (case (peek-token-type)
                    (:directive (parse-directive))
                    (:ident (parse-ident))
                    (t :error))))
        (when (and (atom defs) (eq defs :error))
          (return))
        (dolist (def (if (atom defs)
                         (list defs)
                       defs))
          (when def
            (push def ast)))))
    (nreverse ast)))

(defun parse-directive ()
  (case (peek-token-value)
    (:define (parse-directive-define))
    (:include (parse-directive-ignore))
    (:pragma (parse-directive-ignore))
    (:ifdef (parse-directive-ignore))
    (:if (parse-directive-if))
    (:elif (parse-directive-elif))
    (:else (parse-directive-stop))
    (:endif (parse-directive-stop))
    (t (error-unknown-token))))

(defun parse-directive-define ()
  (eat-token :directive :define)
  (eat-whitespace-or-comment :eat-newline nil)
  (let ((*eat-whitespace-or-comment-automatically* nil))
    (let ((name (eat-token-value :ident))
          (value (eat-tokens-of-line)))
      (make-c-macro :name name :value value))))

(defun parse-directive-ignore ()
  (eat-tokens-of-line)
  nil)

(defun parse-directive-if ()
  (eat-directive :if)
  (parse-directive-if1 :eat-endif t))

(defun parse-directive-elif ()
  (eat-directive :elif)
  (parse-directive-if1 :eat-endif nil))

(defun parse-directive-if1 (&key eat-endif)
  (let ((if-condition (eat-tokens-of-line))
        (if-body (try-parse))
        else-body)
    (case (peek-token-value)
      (:elif
       (setf else-body (try-parse)))
      (:else
       (eat-directive :else)
       (setf else-body (try-parse)))
      (:endif
       )
      (t
       (error-unknown-token)))
    (when eat-endif
      (eat-directive :endif))
    (make-c-if :condition if-condition
               :body if-body
               :else else-body)))

(defun parse-directive-stop ()
  (setf *stop-parse* t)
  nil)

(defun parse-ident ()
  (case (peek-token-value)
    (:typedef (parse-typedef))
    (:extern (parse-extern))
    (t (parse-function-decl))))

(defmacro restore-parse-error (&body body)
  (let ((gtoken (gensym)))
    `(let ((,gtoken *token*))
       (handler-case
           (progn ,@body)
         (error (c)
           (setf *token* ,gtoken)
           nil)))))

(defun parse-function-decl ()
  (let (return-type name args)
    (setf return-type (butlast (parse-ident-list)))
    (uneat-token)
    (setf name (eat-token-value :ident))
    (eat-punc #\()
    (setf args (parse-function-parameter-list))
    (eat-punc #\))
    (eat-punc #\;)
    (make-c-func :return-type return-type
                 :name name
                 :args args)))

(defun parse-function-callback ()
  (let (return-type type args)
    (setf return-type (parse-ident-list))
    (eat-punc #\()
    (setf type (parse-ident-list))
    (eat-punc #\))
    (eat-punc #\()
    (setf args (parse-function-parameter-list))
    (eat-punc #\))
    (eat-punc #\;)
    (make-c-callback :return-type return-type
                     :type type
                     :args args)))

(defun parse-function-parameter-list ()
  (prog1
      (parse-separated-ident-list #\,)
    (when (token-type-p :vaarg)
      (let ((token (peek-token)))
        (error "Variable arguments not supported. (line ~D, column ~D)"
               (token-lineno token) (token-column token))
        ))))


(defun parse-extern ()
  (eat-ident :extern)
  (eat-token :string "C")
  (eat-punc #\{)
  (prog1
      (try-parse)
    (eat-punc #\})))

(defun parse-typedef ()
  (eat-ident :typedef)
  (case (peek-token-value)
    (:struct
     (parse-typedef-struct))
    (:enum
     (parse-typedef-enum))
    (t
     (or (restore-parse-error
          (parse-function-callback))
         (parse-typedef-simple)))))

(defun parse-typedef-struct ()
  (eat-ident :struct)
  (parse-typedef-complex 'parse-typedef-struct-body 'make-c-struct))

(defun parse-typedef-struct-body ()
  (parse-separated-ident-list #\;))

(defun parse-typedef-enum ()
  (eat-ident :enum)
  (parse-typedef-complex 'parse-typedef-enum-body 'make-c-enum))

(defun parse-typedef-enum-body ()
  (let ((value 0)
        symbol body)
    (loop
      (setf symbol (eat-token-value :ident))
      (when (operator-p :=)
        (eat-operator :=)
        (setf value (eat-token-value)))
      (push (list symbol value) body)
      (when (punc-p #\})
        (return))
      (eat-punc #\,)
      (incf value))
    (nreverse body)))

(defun parse-typedef-complex (body-parser struct-maker)
  (let (name body alias)
    (when (ident-p)
      (setf name (eat-token-value :ident)))
    (eat-punc #\{)
    (setf body (funcall body-parser))
    (eat-punc #\})
    (setf alias (parse-typedef-alias))
    (eat-punc #\;)
    ;; –¼‘O‚Ì•â³
    ;;   typedef struct { } Foo;
    ;;   typedef struct _Foo { } Foo;
    (when (and alias
               (or (not name)
                   (string-match "^_" (string name))))
      (setf name (car alias)
            alias (cdr alias)))
    (cons
     (funcall struct-maker :name name :members body)
     (alias->c-types name alias))))

(defun alias->c-types (name alias)
  (flet ((ptr-type-p (e)
           (listp e))
         (raw-type (e)
           (cadr e))
         (ptr-type (e)
           (car e))
         (make-ptr (e ptr)
           (cons ptr (if (listp e) e (list e))))
         )
    (mapcar #'(lambda (e)
                (if (ptr-type-p e)
                    (make-c-type :type (raw-type e)
                                 :decl (make-ptr name (ptr-type e)))
                  (make-c-type :type e :decl name)))
            alias)))

(defun parse-typedef-alias ()
  (mapcar #'car (parse-separated-ident-list #\,)))

(defun parse-typedef-simple ()
  (let (type-decl alias)
    (while (and (not (punc-p #\;))
                (not (punc-p #\,)))
      (push (eat-token-value :ident) type-decl))
    (when (punc-p #\,)
      (eat-punc #\,)
      (setf alias (parse-typedef-alias)))
    (push (pop type-decl) alias)
    (eat-punc #\;)
    (alias->c-types (nreverse type-decl) alias)))

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
