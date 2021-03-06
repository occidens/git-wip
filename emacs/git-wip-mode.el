;;; git-wip-mode.el --- Use git-wip to record every buffer save

;; Copyright (C) 2013  Jerome Baum

;; Author: Jerome Baum <jerome@jeromebaum.com>
;; Version: 0.1
;; Keywords: vc

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;;; Code:

(eval-when-compile
  (require 'cl))

(require 'vc)

(defvar git-wip-buffer-name " *git-wip*"
  "Name of the buffer to which git-wip's output will be echoed")

(defvar git-wip-vc-symbol 'Git)
(defvar git-wip-debug nil)
(defvar git-wip-file-name nil)

(defvar git-wip-path
  (let* ((lib-path
	  (file-name-directory
	   (or load-file-name (locate-library "git-wip-mode"))))
	 (lib-parent-path
	  (file-name-directory (directory-file-name lib-path)))
	 (git-exec-path
	  (parse-colon-path
            (replace-regexp-in-string
             "[ \t\n\r]+\\'" ""
             (shell-command-to-string "git --exec-path"))))
	 (exec-path
	  (append (list lib-path lib-parent-path)
		  exec-path
		  git-exec-path)))
    (executable-find "git-wip"))
  "Path to the git-wip executable.

The default location is set by searching the following paths in
order:

- the library location of this file
  (for installations from a package)
- the parent directory of the library location if this file
  (for installations from a git clone)
- the current `exec-path'
- the git exec-path")

(defun git-wip-git-p ()
  "Return t if git-wip can be run on the current buffer."
  (and git-wip-path
       (eq (vc-backend (buffer-file-name)) git-wip-vc-symbol)))

(defun git-wip-when-done (proc &optional change)
  ""
  (when (eq 'exit (process-status proc))
    (with-current-buffer (process-buffer proc)
      (if (= 0 (process-exit-status proc))
	  (prog1
	      (message "Write and git-wip'd %s"
		       git-wip-file-name)
	    (unless git-wip-debug
	      (kill-buffer (current-buffer))))
	(message "Git-wip failed with exit code %d"
		 (process-exit-status proc))))))

(defun git-wip-after-save ()
  (when (git-wip-git-p)
    (let* ((buf (generate-new-buffer git-wip-buffer-name))
	   (filename (buffer-file-name))
	   (basename (file-name-nondirectory filename))
	   (msg (format "WIP from emacs: %s" basename))
	   (args (append
		  `("save" ,msg)
		  (unless git-wip-debug '("--editor"))
		  `("--" ,basename)))
	   (proc (let ((process-connection-type nil))
		   (apply #'start-process
			  "git-wip" buf git-wip-path args))))
      (with-current-buffer buf
	(set (make-local-variable 'git-wip-file-name) filename)
	(set-process-sentinel proc #'git-wip-when-done)
	proc))))

;;;###autoload
(define-minor-mode git-wip-mode
  "Toggle git-wip mode.
With no argument, this command toggles the mode.
Non-null prefix argument turns on the mode.
Null prefix argument turns off the mode.

When git-wip mode is enabled, git-wip will be called every time
you save a buffer."
  ;; The initial value.
  nil
  ;; The indicator for the mode line.
  " WIP"
  :group 'git-wip

  ;; (de-)register our hook
  (if git-wip-mode
      (add-hook 'after-save-hook 'git-wip-after-save nil t)
    (remove-hook 'after-save-hook 'git-wip-after-save t)))

(defun git-wip-mode-if-git ()
  (when (string= (vc-backend (buffer-file-name)) "Git")
    (git-wip-mode t)))

(add-hook 'find-file-hook 'git-wip-mode-if-git)

(provide 'git-wip-mode)
;;; git-wip-mode.el ends here
