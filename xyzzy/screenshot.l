;; http://www.microsoft.com/japan/msdn/windows/windowsxp/xpvisualstyles.aspx

(require "cairo")

(c:*define-dll-entry
 winapi::HBITMAP CreateCompatibleBitmap (winapi::HDC c:int c:int)
  "gdi32")

(c:*define-dll-entry
  winapi::BOOL
  PrintWindow (
               winapi::HWND
               winapi::HDC
               winapi::UINT)
  "user32")

(defun screenshot ()
  (interactive)
  (let* ((hwnd (get-window-handle))
         (hdc (winapi::GetDC hwnd))
         (hdcMem (winapi::CreateCompatibleDC hdc))
         (rc (winapi::make-RECT)))
    (winapi::GetWindowRect (get-window-handle) rc)
    (let ((hbitmap
           (CreateCompatibleBitmap hdc
                                   (- (winapi::RECT-right rc)
                                      (winapi::RECT-left rc))
                                   (- (winapi::RECT-bottom rc)
                                      (winapi::RECT-top rc)))))
      (winapi::SelectObject hdcMem hbitmap)
      (PrintWindow (get-window-handle) hdcMem 0)
      (cairo:with-cairo-surface (sur (cairo:cairo-win32-surface-create hdcMem))
        (cairo:with-output-to-png (sur (merge-pathnames
                                        "foo.png"
                                        (get-special-folder-location :desktop)))))
      (winapi::DeleteObject hbitmap)
      (winapi::DeleteObject hdcMem)
      (winapi::ReleaseDC hwnd hdc))))
