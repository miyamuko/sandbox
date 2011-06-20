
(setf *c-token*
(tokenize "
typedef struct _SECURITY_ATTRIBUTES {
    DWORD  nLength;               // 構造体サイズ
    LPVOID lpSecurityDescriptor;  // セキュリティデスクリプタ
    BOOL   bInheritHandle;        // 継承フラグ
} SECURITY_ATTRIBUTES, *PSECURITY_ATTRIBUTES, *LPSECURITY_ATTRIBUTES;
"))

*c-token*

(defvar *c-token* nil)

(defun skip (type token)
  (setf *c-token* (cdr *c-token*)))

(defun peek-type ()
  (car (car *c-token*)))

(defun scan ()
  (prog1
      (car *c-token*)
    (skip nil nil)))

(defun parse-typedef ()
  (skip :ident 'typedef)
  (case (peek-type)
    (:enum
     (parse-typedef-enum))
    (:struct
     (parse-typedef-struct))
    (t
     (parse-typedef-type))))

(defun parse-typedef-struct ()
  (skip :ident 'struct)
  (when (eq (peek-type) :ident)
    (setf name (cadddr scan))))
