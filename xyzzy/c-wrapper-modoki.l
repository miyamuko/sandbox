#|
Gauche の c-wrapper のように C のソースから直接 FFI の定義を生成するマクロ。
まだ、関数と構造体と列挙型だけ。

(c:define-c-type (winapi:BYTE *) LPBYTE)

(define-c-struct-wrapper "
typedef struct _PROCESS_INFORMATION {
    HANDLE hProcess;     // プロセスのハンドル
    HANDLE hThread;      // プライマリスレッドのハンドル
    DWORD  dwProcessId;  // プロセスID
    DWORD  dwThreadId;   // プライマリスレッドID
} PROCESS_INFORMATION, *PPROCESS_INFORMATION, *LPPROCESS_INFORMATION;
")

(define-c-struct-wrapper "
typedef struct _SECURITY_ATTRIBUTES {
    DWORD  nLength;               // 構造体サイズ
    LPVOID lpSecurityDescriptor;  // セキュリティデスクリプタ
    BOOL   bInheritHandle;        // 継承フラグ
} SECURITY_ATTRIBUTES, *PSECURITY_ATTRIBUTES, *LPSECURITY_ATTRIBUTES;
")

(define-c-struct-wrapper "
typedef struct _STARTUPINFO {
    DWORD  cb;              // 構造体サイズ
    LPTSTR  lpReserved;     // 予約(0)
    LPTSTR  lpDesktop;      // デスクトップ
    LPTSTR  lpTitle;        // ウィンドウタイトル
    DWORD  dwX;             // x位置
    DWORD  dwY;             // y位置
    DWORD  dwXSize;         // xサイズ
    DWORD  dwYSize;         // yサイズ
    DWORD  dwXCountChars;   // 文字幅
    DWORD  dwYCountChars;   // 文字高
    DWORD  dwFillAttribute; // 文字色・背景色
    DWORD  dwFlags;         // フラグ
    WORD   wShowWindow;     // ウィンドウ表示形式
    WORD   cbReserved2;     // 予約(0)
    LPBYTE lpReserved2;     // 予約(0)
    HANDLE hStdInput;       // 標準入力
    HANDLE hStdOutput;      // 標準出力
    HANDLE hStdError;       // 標準エラー出力
} STARTUPINFO, *LPSTARTUPINFO;
")

(define-c-function-wrapper "
BOOL CreateProcess(
  LPCTSTR lpApplicationName,                 // 実行可能モジュールの名前
  LPTSTR lpCommandLine,                      // コマンドラインの文字列
  LPSECURITY_ATTRIBUTES lpProcessAttributes, // セキュリティ記述子
  LPSECURITY_ATTRIBUTES lpThreadAttributes,  // セキュリティ記述子
  BOOL bInheritHandles,                      // ハンドルの継承オプション
  DWORD dwCreationFlags,                     // 作成のフラグ
  LPVOID lpEnvironment,                      // 新しい環境ブロック
  LPCTSTR lpCurrentDirectory,                // カレントディレクトリの名前
  LPSTARTUPINFO lpStartupInfo,               // スタートアップ情報
  LPPROCESS_INFORMATION lpProcessInformation // プロセス情報
);
" "kernel32" "CreateProcessA")


(define-c-enum-wrapper "
typedef enum {
    KSPROPERTY_OVERLAYUPDATE_INTERESTS,
    KSPROPERTY_OVERLAYUPDATE_CLIPLIST = 0x1,
    KSPROPERTY_OVERLAYUPDATE_PALETTE = 0x2,
    KSPROPERTY_OVERLAYUPDATE_COLORKEY = 0x4,
    KSPROPERTY_OVERLAYUPDATE_VIDEOPOSITION = 0x8,
    KSPROPERTY_OVERLAYUPDATE_DISPLAYCHANGE = 0x10,
    KSPROPERTY_OVERLAYUPDATE_COLORREF = 0x10000000,
    KSPROPERTY_OVERLAYUPDATE_COLORREF2,
} KSPROPERTY_OVERLAYUPDATE, *LPKSPROPERTY_OVERLAYUPDATE;
")

(define-c-enum-wrapper "
typedef enum _MEMORY_RESOURCE_NOTIFICATION_TYPE {
    LowMemoryResourceNotification,
    HighMemoryResourceNotification
} MEMORY_RESOURCE_NOTIFICATION_TYPE;
")


(let ((si (make-STARTUPINFO))
      (info (make-PROCESS_INFORMATION)))
  (setf (STARTUPINFO-cb si) (c:c-struct-size-of STARTUPINFO))
  (when (zerop (CreateProcess 0 (si:make-string-chunk "notepad")
                              0 0 0 0 0 0
                              si pri))
    (error "CreateProcess failed"))
  (values
   (PROCESS_INFORMATION-dwThreadId pri)
   (PROCESS_INFORMATION-dwProcessId pri)
   (PROCESS_INFORMATION-hProcess pri)
   (PROCESS_INFORMATION-hThread pri)))
|#


;;;

(defmacro define-c-wrapper (c-src dll-name)
  )

;;; 正規表現

(defun capture (&rest args)
  (format nil "\\(~{~A~}\\)" args))

(defun group (&rest args)
  (format nil "\\(?:~{~A~}\\)" args))

(defun maybe (&rest args)
  (format nil "\\(?:\\(?:~{~A~}\\)?\\)" args))

(defun any (&rest args)
  (format nil "\\(?:~{~A~^\\|~}\\)" args))

(defun repeat* (&rest args)
  (format nil "\\(?:\\(?:~{~A~}\\)*\\)" args))

(defun repeat+ (&rest args)
  (format nil "\\(?:\\(?:~{~A~}\\)+\\)" args))

(let ((space+ "[ \t]+")
      (space* "[ \t]*")
      (ident "\\**[ \t]*\\(?:[a-zA-Z_][a-zA-Z0-9_]*\\)"))
  (defparameter *typedef-simple-regexp* (concat "typedef" space+
                                                (capture ident (repeat* space+ ident))
                                                space+
                                                (capture
                                                 ident
                                                 (repeat* space* "," space* ident))
                                                ";"
                                                ))

  (defparameter *typedef-complex-regexp* (concat "typedef" space+
                                                 (capture (any "struct" "enum")) space+
                                                 (capture (maybe ident)) space*
                                                 "{" (capture ".*?") "}" space*
                                                 (capture
                                                  ident
                                                  (repeat* space* "," space* ident))
                                                 ";"
                                                 ))
  )

;;; 関数

(defmacro define-c-function-wrapper (c-src dll-name &optional export-name)
  `(progn
     ,@(define-c-function-wrapper-helper c-src dll-name export-name)))

(defun define-c-function-wrapper-helper (c-src dll-name &optional export-name)
  (when (symbolp c-src)
    (setf c-src (symbol-value c-src)))
  (let ((defs (parse-c-function c-src)))
    `((c:define-dll-entry
        ,(car defs)
        ,(cadr defs)
        ,(mapcar #'car (caddr defs))
        ,dll-name ,export-name))))

(defun parse-c-function (c-src)
  (setf c-src (cleanup-c-src c-src))
  (unless (string-match "\\([a-zA-Z0-9_]+\\) \\([a-zA-Z0-9_]+\\) *(\\(.+?\\));"
                        c-src)
    (error "parse error"))
  (let ((ret-type (match-symbol 1))
        (func-name (match-symbol 2))
        (func-body (match-string 3)))
    (let ((args (parse-c-function-arguments func-body)))
      (list ret-type func-name args))))

(defun parse-c-function-arguments (c-src)
  (mapcar #'(lambda (field)
              (unless (string-match "\\([a-zA-Z0-9_]+\\) \\([a-zA-Z0-9_]+\\)" field)
                (error (format nil "parse error: ~A" field)))
              (list (match-symbol 1)
                    (match-symbol 2)))
          (split-string (string-trim " " c-src) #\,)))

;;; 構造体

(defmacro define-c-struct-wrapper (c-src)
  `(progn
     ,@(define-c-struct-wrapper-helper c-src)))

(defun define-c-struct-wrapper-helper (c-src)
  (let ((defs (parse-c-typedef-complex c-src #'parse-c-struct-fields)))
    `((c:define-c-struct ,(car defs)
        ,@(cadr defs))
      ,@(mapcar #'(lambda (alias)
                    `(c:define-c-type ,@alias))
                (caddr defs)))))

(defun parse-c-struct-fields (c-src)
  (mapcar #'(lambda (field)
              (unless (string-match "\\([a-zA-Z0-9_]+\\) \\([a-zA-Z0-9_]+\\)" field)
                (error (format nil "parse error: ~A" field)))
              (list (match-symbol 1)
                    (match-symbol 2)))
          (split-string (string-trim " " c-src) #\;)))

;;; enum

(defmacro define-c-enum-wrapper (c-src)
  `(progn
     ,@(define-c-enum-wrapper-helper c-src)))

(defun define-c-enum-wrapper-helper (c-src)
  (let ((defs (parse-c-typedef-complex c-src #'parse-c-enum-fields)))
    `((c:define-c-type c:int ,(car defs))
      ,@(mapcar #'(lambda (var)
                    `(c:define ,@var))
                (cadr defs))
      ,@(mapcar #'(lambda (alias)
                    `(c:define-c-type ,@alias))
                (caddr defs)))))

(defun parse-c-enum-fields (c-src)
  (let ((last-val -1))
    (mapcar #'(lambda (field)
                (unless (string-match "\\([a-zA-Z0-9_]+\\)\\(?: = \\(0x\\)?\\([0-9]+\\)\\)?" field)
                  (error (format nil "parse error: ~A" field)))
                (let ((var (match-symbol 1))
                      (hex (match-string 2))
                      (val (match-string 3)))
                  (list var
                        (if val
                            (setf last-val (parse-integer val :radix (if hex 16 10)))
                          (incf last-val)))))
            (split-string (string-trim " " c-src) #\,))))

;;; #define

(defmacro define-c-macro-wrapper (c-src)
  `(progn
     ,(define-c-macro-wrapper-helper c-src)))

(defun define-c-macro-wrapper-helper (c-src)
  (let ((defs (parse-c-macro c-src)))
    (if (and (atom (cadr defs))
             (fboundp (cadr defs)))
        ;; #define FooA Foo
        `(setf (symbol-function ',(car defs))
               (symbol-function ',(cadr defs)))
      ;; #define Foo 1
      `(c:*define ,@defs))))

(defun parse-c-macro (c-src)
  (setf c-src (cleanup-c-src c-src))
  (unless (string-match "#define[ \t]+\\([a-zA-Z0-9_]+\\)[ \t]+\\(.*\\)"
                        c-src)
    (error "parse error"))
  (let ((macro-name (match-symbol 1))
        (macro-body (match-string 2)))
    (let ((body (parse-c-macro-body macro-body)))
      (list macro-name body))))

(defun parse-c-macro-body (c-src)
  (cond ((string-match "^N?\"\\(.*?\\)\"" c-src)
         (match-string 1))
        ((string-match "^\\([a-zA-Z_][a-zA-Z0-9_]*\\)" c-src)
         (match-symbol 1))
        (t
         (infix->prefix c-src))))

(defun infix->prefix (string)
  (let ((*read-default-float-format* 'double-float)
	(ed::*calc-token* (let ((token nil))
			(with-input-from-string (s string)
			  (do ((tok (ed::calc-next-token s) (ed::calc-next-token s)))
			      ((null tok) (nreverse token))
			    (push tok token))))))
    (let ((expr (and ed::*calc-token* (ed::calc-expr))))
      (when ed::*calc-token*
        (error "unexpected ~A." (ed::calc-token-string (car ed::*calc-token*))))
      (reintern-calc-package expr))))

;; シンボルは calc::DWORD などになるので winapi::DWORD に変換
(defun reintern-calc-package (list)
  (if (atom list)
      (if (symbolp list)
          (intern (string list))
        list)
    (mapcar #'reintern-calc-package list)))


;;; typedef

(defun parse-c-typedef-complex (c-src body-parser)
  (setf c-src (cleanup-c-src c-src))
  (unless (string-match *typedef-complex-regexp* c-src)
    (error "parse error2"))
  (let ((name (match-symbol 2))
        (body-decl (match-string 3))
        (alias-decl (match-string 4)))
    (let ((body (funcall body-parser body-decl))
          (aliases (parse-c-typedef-aliases alias-decl)))
      (when (and (car aliases)
                 (zerop (caar aliases)))
        (setf name (cadr (car aliases))
              aliases (cdr aliases)))
      (setf aliases (mapcar #'(lambda (alias)
                                (let ((type name))
                                  (dotimes (i (car alias))
                                    (setf type (list type '*)))
                                  (list type (cadr alias))))
                            aliases))
    (list name body aliases))))

(defun parse-c-typedef-aliases (c-src)
  (mapcar #'(lambda (alias)
              (string-match "\\(\\**\\)\\([a-zA-Z0-9_]+\\)" alias)
              (let ((ptr (match-string 1))
                    (name (match-symbol 2)))
                (list (length ptr) name)))
          (split-string c-src #\,)))


;;; ユーティリティ

(defun cleanup-c-src (c-src)
  ; キャスト
  (setf c-src (substitute-string c-src "([^()]*?)(\\([^()]*?\\))" "\\1"))
  ; 型指定
  (setf c-src (substitute-string c-src "\\([0-9]+\\)[ULFD]+" "\\1"))
  ; 継続行
  (setf c-src (substitute-string c-src "\\\\\n" ""))
  ; コメント
  (setf c-src (substitute-string c-src "//.*$" ""))
  ; 余計な空白・改行
  (setf c-src (substitute-string c-src "[ \r\t\f\n]+" " "))
  c-src)

(defun match-symbol (group)
  (let ((name (match-string group)))
    (when name
      (or (find-symbol name :winapi)
          (intern name)))))
