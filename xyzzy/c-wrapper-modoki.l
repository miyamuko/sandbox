#|
Gauche �� c-wrapper �̂悤�� C �̃\�[�X���璼�� FFI �̒�`�𐶐�����}�N���B
�܂��A�֐��ƍ\���̂Ɨ񋓌^�����B

(c:define-c-type (winapi:BYTE *) LPBYTE)

(define-c-struct-wrapper "
typedef struct _PROCESS_INFORMATION {
    HANDLE hProcess;     // �v���Z�X�̃n���h��
    HANDLE hThread;      // �v���C�}���X���b�h�̃n���h��
    DWORD  dwProcessId;  // �v���Z�XID
    DWORD  dwThreadId;   // �v���C�}���X���b�hID
} PROCESS_INFORMATION, *PPROCESS_INFORMATION, *LPPROCESS_INFORMATION;
")

(define-c-struct-wrapper "
typedef struct _SECURITY_ATTRIBUTES {
    DWORD  nLength;               // �\���̃T�C�Y
    LPVOID lpSecurityDescriptor;  // �Z�L�����e�B�f�X�N���v�^
    BOOL   bInheritHandle;        // �p���t���O
} SECURITY_ATTRIBUTES, *PSECURITY_ATTRIBUTES, *LPSECURITY_ATTRIBUTES;
")

(define-c-struct-wrapper "
typedef struct _STARTUPINFO {
    DWORD  cb;              // �\���̃T�C�Y
    LPTSTR  lpReserved;     // �\��(0)
    LPTSTR  lpDesktop;      // �f�X�N�g�b�v
    LPTSTR  lpTitle;        // �E�B���h�E�^�C�g��
    DWORD  dwX;             // x�ʒu
    DWORD  dwY;             // y�ʒu
    DWORD  dwXSize;         // x�T�C�Y
    DWORD  dwYSize;         // y�T�C�Y
    DWORD  dwXCountChars;   // ������
    DWORD  dwYCountChars;   // ������
    DWORD  dwFillAttribute; // �����F�E�w�i�F
    DWORD  dwFlags;         // �t���O
    WORD   wShowWindow;     // �E�B���h�E�\���`��
    WORD   cbReserved2;     // �\��(0)
    LPBYTE lpReserved2;     // �\��(0)
    HANDLE hStdInput;       // �W������
    HANDLE hStdOutput;      // �W���o��
    HANDLE hStdError;       // �W���G���[�o��
} STARTUPINFO, *LPSTARTUPINFO;
")

(define-c-function-wrapper "
BOOL CreateProcess(
  LPCTSTR lpApplicationName,                 // ���s�\���W���[���̖��O
  LPTSTR lpCommandLine,                      // �R�}���h���C���̕�����
  LPSECURITY_ATTRIBUTES lpProcessAttributes, // �Z�L�����e�B�L�q�q
  LPSECURITY_ATTRIBUTES lpThreadAttributes,  // �Z�L�����e�B�L�q�q
  BOOL bInheritHandles,                      // �n���h���̌p���I�v�V����
  DWORD dwCreationFlags,                     // �쐬�̃t���O
  LPVOID lpEnvironment,                      // �V�������u���b�N
  LPCTSTR lpCurrentDirectory,                // �J�����g�f�B���N�g���̖��O
  LPSTARTUPINFO lpStartupInfo,               // �X�^�[�g�A�b�v���
  LPPROCESS_INFORMATION lpProcessInformation // �v���Z�X���
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


;;; �֐�

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

;;; �\����

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

;;; typedef

(defun parse-c-typedef-complex (c-src body-parser)
  (setf c-src (cleanup-c-src c-src))
  (unless (string-match "typedef \\(?:enum\\|struct\\) *\\([a-zA-Z0-9_]+\\)? *{\\(.+?\\)} *\\(.+?\\);"
                        c-src)
    (error "parse error2"))
  (let ((name (match-symbol 1))
        (body-decl (match-string 2))
        (alias-decl (match-string 3)))
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


;;; ���[�e�B���e�B

(defun cleanup-c-src (c-src)
  (setf c-src (substitute-string c-src "//.*$" ""))
  (setf c-src (substitute-string c-src "[ \r\t\f\n]+" " "))
  c-src)

(defun match-symbol (group)
  (let ((name (match-string group)))
    (when name
      (or (find-symbol name :winapi)
          (intern name)))))