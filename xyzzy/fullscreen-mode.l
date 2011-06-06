;; なんちゃって全画面表示モード for xyzzy
;;
;;   - M-x toggle-fullscreen-mode
;;   - [表示] メニュー - [全画面表示]
;;   - メニューとコマンドバーも非表示にする
;;     - カーソルを画面上部に移動させるとメニューを表示する
;;   - ミニバッファ、ステータスバーは非表示にできない
;;   - モードライン、ルーラー、ステータスバー、行番号などはそのまま
;;     - こいつらも消して広くできるけど、さすがに不便だよね
;;
;; 既知のバグ:
;;
;;   - セカンダリディスプレイで全画面化するとウィンドウが消える
;;   - ディスプレイ解像度を 1280x1024 で決め打ちしている

(defparameter *last-current-menu* nil)
(defparameter *last-command-bar* nil)
(defparameter *last-window-style* nil)
(defparameter *last-window-rect* nil)
(defparameter *fullscreen-mode-p* nil)

(defun toggle-fullscreen-mode ()
  (interactive)
  (if *fullscreen-mode-p*
      (leave-fullscreen-mode)
    (enter-fullscreen-mode)))

(defun enter-fullscreen-mode ()
  (interactive)
  (setf *fullscreen-mode-p* t)
  (let ((hwnd (get-window-handle)))
    (setf *last-current-menu* (current-menu))
    (setf *last-command-bar* (current-command-bar))
    (setf *last-window-style* (get-window-style hwnd))
    (setf *last-window-rect* (get-window-rect hwnd))

    (set-menu nil)
    (mapc 'hide-command-bar *last-command-bar*)
    (set-window-style hwnd (make-fullscreen-style *last-window-style*))
    (move-window hwnd 0 0 1280 1024) ;; FIXME
    ))

(defun leave-fullscreen-mode ()
  (interactive)
  (setf *fullscreen-mode-p* nil)
  (let ((hwnd (get-window-handle)))
    (set-menu *last-current-menu*)
    (mapc 'show-command-bar *last-command-bar*)
    (set-window-style hwnd *last-window-style*)
    (move-window-rect hwnd *last-window-rect*)

    (setf *last-current-menu* nil)
    (setf *last-command-bar* nil)
    (setf *last-window-style* nil)
    (setf *last-window-rect* nil)
    ))

(defun current-command-bar ()
  (mapcan #'(lambda (command-bar)
              (multiple-value-bind (pkg sym _ visible-p _ _ _ _)
                  (values-list command-bar)
                (when visible-p
                  (list (find-symbol sym pkg)))))
          ed::*command-bar-list*))

(defun make-fullscreen-style (current-style)
  (logxor current-style
          (logior
           winapi:WS_CAPTION
           winapi:WS_BORDER
           winapi:WS_THICKFRAME
           winapi:WS_MAXIMIZE
           )))

(defun get-window-rect (hwnd)
  (let ((rect (winapi:make-RECT)))
    (winapi:GetWindowRect (get-window-handle) rect)
    (list (winapi:RECT-left rect)
          (winapi:RECT-top rect)
          (winapi:RECT-right rect)
          (winapi:RECT-bottom rect))))

(defun move-window-rect (hwnd rect)
  (multiple-value-bind (left top right bottom)
      (values-list rect)
    (let ((x left)
          (y top)
          (w (- right left))
          (h (- bottom top)))
      (move-window hwnd x y w h))))

(defun move-window (hwnd x y w h)
  (winapi:MoveWindow hwnd x y w h 1))

(defun set-window-style (hwnd style)
  (winapi:SetWindowLong hwnd winapi:GWL_STYLE style))

(defun get-window-style (hwnd)
  (winapi:GetWindowLong hwnd winapi:GWL_STYLE))


;; マウスを画面上部に移動するとメニューを表示する

(defun fullscreen-mode-on-mouse-move ()
  (interactive)
  (when (and *fullscreen-mode-p*
             *last-current-menu*)
    (let ((y (second (get-cursor-position))))
      (if (< y 40)
          (set-menu *last-current-menu*)
        (set-menu nil)))))
(global-set-key #\MouseMove 'fullscreen-mode-on-mouse-move)

(defun get-cursor-position ()
  (let ((p (winapi:make-POINT)))
    (winapi:GetCursorPos p)
    (list (winapi:POINT-x p)
          (winapi:POINT-y p))))

;; 表示メニューに追加

(defvar *fullscreen-mode-menu-tag* 'toggle-fullscreen-mode)
(defvar *fullscreen-mode-menu-name* "全画面表示(&X)")

(defun fullscreen-mode-setup-menu ()
  (let ((menu (get-menu *app-menu* 'ed::view)))
    (when menu
      (delete-menu menu *fullscreen-mode-menu-tag*)
      (add-menu-item  menu
                      *fullscreen-mode-menu-tag*
                      *fullscreen-mode-menu-name*
                      'toggle-fullscreen-mode
                      #'(lambda () (if *fullscreen-mode-p* :check))))))

(if *app-menu*
    ;; xyzzy 起動済みならすぐに追加
    (fullscreen-mode-setup-menu)
  ;; xyzzy 起動中/ダンプ中なら *init-app-menus-hook* に引っ掛けて実行
  (add-hook '*init-app-menus-hook* 'fullscreen-mode-setup-menu))
