(require "alexandria")

(load "winhttp.l")

(use-package :winhttp)

(progn
  (setf hSession (WinHttpOpen (si:make-string-chunk "Sample Application/1.0")
                              WINHTTP_ACCESS_TYPE_DEFAULT_PROXY
                              WINHTTP_NO_PROXY_NAME
                              WINHTTP_NO_PROXY_BYPASS
;                              WINHTTP_FLAG_ASYNC
                              0
                              ))

  (setf szHostName (si:make-chunk nil 256))
  (setf szUrlPath (si:make-chunk nil 2048))
  (setf wcharSize 2)

  (setf szUrl (L "http://www.yahoo.co.jp/"))
  (setf szUrl (L "http://ftp.jaist.ac.jp/pub/mozilla.org/firefox/releases/9.0.1/win32/ja/Firefox%20Setup%209.0.1.exe"))

  (setf urlComponents (make-URL_COMPONENTS))
  (RtlZeroMemory urlComponents (c:c-struct-size-of URL_COMPONENTS))

  (setf (URL_COMPONENTS-dwStructSize urlComponents)     (c:c-struct-size-of URL_COMPONENTS)
        (URL_COMPONENTS-lpszHostName urlComponents)     (si:chunk-data szHostName)
        (URL_COMPONENTS-dwHostNameLength urlComponents) (/ (si:chunk-size szHostName) wcharSize)
        (URL_COMPONENTS-lpszUrlPath urlComponents)      (si:chunk-data szUrlPath)
        (URL_COMPONENTS-dwUrlPathLength urlComponents)  (/ (si:chunk-size szUrlPath) wcharSize))

  (WinHttpCrackUrl szUrl
                   (/ (si:chunk-size szUrl) wcharSize)
                   0
                   urlComponents)

  (ed:convert-encoding-to-internal
   *encoding-utf16le*
   (si:unpack-string szHostName 0
                     (* (URL_COMPONENTS-dwHostNameLength urlComponents)
                        wcharSize)
                     nil))

  (setf hConnect (WinHttpConnect hSession szHostName INTERNET_DEFAULT_PORT 0))
  (setf hRequest (WinHttpOpenRequest hConnect (L "GET") szUrlPath NULL WINHTTP_NO_REFERER WINHTTP_DEFAULT_ACCEPT_TYPES 0))

  ; 別スレッドから呼ばれるからか xyzzy がクラッシュしてしまう
  ;  (WinHttpSetStatusCallback hRequest #'WINHTTP_STATUS_CALLBACK WINHTTP_CALLBACK_FLAG_ALL_COMPLETIONS 0)
  ;  (setf winhttp::*winhttp-status-callback-func* #'(lambda (&rest args)
  ;                                                    (ed::msgbox "~S" args)))

  (WinHttpSendRequest hRequest WINHTTP_NO_ADDITIONAL_HEADERS 0 WINHTTP_NO_REQUEST_DATA 0 0 0)
  (loop
    (setf r (WinHttpReceiveResponse hRequest NULL))
    (when (= r 1)
      (return))
    (msgbox (format-date-string "%H:%M:%S"))
    (sleep-for 1))

  (setf data-list nil)
  (setf dwSize (si:make-chunk nil 4))
  (loop
    (si:pack-int32 dwSize 0 0)
    (WinHttpQueryDataAvailable hRequest dwSize)
    (setf size (si:unpack-int32 dwSize 0))
    (when (<= size 0)
      (return))
    (setf data (si:make-chunk nil size))
    (WinHttpReadData hRequest data size NULL)
    (push (si:unpack-string data 0 size nil) data-list))

  (setf data-str (format nil "~{~A~}" (nreverse data-list)))

  (WinHttpCloseHandle hRequest)
  (WinHttpCloseHandle hConnect)
  (WinHttpCloseHandle hSession)
  (msgbox (si:md5 data-str))
  )
