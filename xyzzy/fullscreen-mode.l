;; �Ȃ񂿂���đS��ʕ\�����[�h for xyzzy
;;
;;   - M-x toggle-fullscreen-mode
;;   - [�\��] ���j���[ - [�S��ʕ\��]
;;   - ���j���[�ƃR�}���h�o�[����\���ɂ���
;;     - �J�[�\������ʏ㕔�Ɉړ�������ƃ��j���[��\������
;;   - �~�j�o�b�t�@�A�X�e�[�^�X�o�[�͔�\���ɂł��Ȃ�
;;   - ���[�h���C���A���[���[�A�X�e�[�^�X�o�[�A�s�ԍ��Ȃǂ͂��̂܂�
;;     - ������������čL���ł��邯�ǁA�������ɕs�ւ����
;;
;; ���m�̃o�O:
;;
;;   - �Z�J���_���f�B�X�v���C�őS��ʉ�����ƃE�B���h�E��������
;;   - �f�B�X�v���C�𑜓x�� 1280x1024 �Ō��ߑł����Ă���

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


;; �}�E�X����ʏ㕔�Ɉړ�����ƃ��j���[��\������

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

;; �\�����j���[�ɒǉ�

(defvar *fullscreen-mode-menu-tag* 'toggle-fullscreen-mode)
(defvar *fullscreen-mode-menu-name* "�S��ʕ\��(&X)")

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
    ;; xyzzy �N���ς݂Ȃ炷���ɒǉ�
    (fullscreen-mode-setup-menu)
  ;; xyzzy �N����/�_���v���Ȃ� *init-app-menus-hook* �Ɉ����|���Ď��s
  (add-hook '*init-app-menus-hook* 'fullscreen-mode-setup-menu))