;;; -*- Mode:Emacs-Lisp -*-

;;; This file is the part of the Insidious Big Brother Database (aka BBDB),
;;; copyright (c) 1991, 1992, 1993 Jamie Zawinski <jwz@netscape.com>.
;;; Interface to VM (View Mail) 5.31 or greater.  See bbdb.texinfo.

;;; The Insidious Big Brother Database is free software; you can redistribute
;;; it and/or modify it under the terms of the GNU General Public License as
;;; published by the Free Software Foundation; either version 1, or (at your
;;; option) any later version.
;;;
;;; BBDB is distributed in the hope that it will be useful, but WITHOUT ANY
;;; WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
;;; FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
;;; details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with GNU Emacs; see the file COPYING.  If not, write to
;;; the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.

;;
;; $Id: bbdb-vm.el,v 1.57 2000/06/14 14:51:34 waider Exp $
;;
;; $Log: bbdb-vm.el,v $
;; Revision 1.57  2000/06/14 14:51:34  waider
;; * Trying another way to get the from field, since the Presentation
;;   buffer hack seems to be somewhat unusable.
;;
;; Revision 1.56  2000/03/31 09:58:50  bbdb-writer
;; (bbdb/vm-get-from): If there's a presentation buffer, get the address
;; from there, since it will be MIME-decoded.
;;
;; Revision 1.55  1998/04/11 07:06:47  simmonmt
;; Colin Rafferty's patch adding autoload cookies back
;;
;; Revision 1.54  1998/02/23 07:14:01  simmonmt
;; Use add-hook, not bbdb-add-hook
;;
;; Revision 1.53  1997/11/02 07:40:18  simmonmt
;; bbdb/vm-annotate-sender now takes REPLACE argument
;;
;;

(require 'bbdb)
(require 'vm)
;(require 'vm-motion) ; not provided, dammit!
;(require 'vm-summary)
(if (not (fboundp 'vm-record-and-change-message-pointer))
    (load-library "vm-motion"))
(if (not (fboundp 'vm-su-from))
    (load-library "vm-summary"))
(or (boundp 'vm-mode-map)
    (load-library "vm-vars"))

(defun bbdb/vm-get-from (msg) 
  "Get the \"From\" address of the specified message. If it's from the current
user, return the recipient addresses instead."
  (setq msg (vm-real-message-of msg))
  (save-excursion
	(save-restriction
	  ;; Select the buffer containing the message.
	  ;; Needed to handle VM virtual folders.
	  (set-buffer (vm-buffer-of msg))
	  ;; If the header is MIME-encoded, mail-extr goes
	  ;; bananas. Actually, mail-extr can't really handle the decoded
	  ;; headers either. Foo.
	  (vm-decode-mime-message-headers msg)
	  (let ((from (or (vm-get-header-contents msg "From:" ", ")
					  (vm-grok-From_-author msg))))
		(if (or (null from)
				(string-match (bbdb-user-mail-names)
							  ;; mail-strip-quoted-names is too broken!
							  ;;(mail-strip-quoted-names from)
							  (or (car (cdr (mail-extract-address-components
											 from)))
								  "")))
			;; if logged in user sent this, use recipients.
			(setq from (or (mail-fetch-field "to") from)))
		from))))

;;;###autoload
(defun bbdb/vm-update-record (&optional offer-to-create)
  "Returns the record corresponding to the current VM message, 
creating or modifying it as necessary.  A record will be created if 
bbdb/mail-auto-create-p is non-nil, or if OFFER-TO-CREATE is true and
the user confirms the creation."
  (save-excursion
    (vm-select-folder-buffer)
    (vm-check-for-killed-summary)
    (vm-error-if-folder-empty)
    (if bbdb-use-pop-up
		(bbdb/vm-pop-up-bbdb-buffer offer-to-create)
      (let ((msg (car vm-message-pointer))
			(inhibit-local-variables nil) ; vm binds this to t...
			(enable-local-variables t)    ; ...or vm bind this to nil.
			(inhibit-quit nil))  ; vm damn well better not bind this to t!
		;; this doesn't optimize the case of moving thru a folder where
		;; few messages have associated records.
		(or (bbdb-message-cache-lookup msg nil)	; nil = current-buffer
			(and msg
				 (let ((from (bbdb/vm-get-from msg)))
				   (if from
					   (bbdb-encache-message
						msg
						(bbdb-annotate-message-sender
						 from t
						 (or (bbdb-invoke-hook-for-value
							  bbdb/mail-auto-create-p)
							 offer-to-create)
						 offer-to-create))))))))))

;;;###autoload
(defun bbdb/vm-annotate-sender (string &optional replace)
  "Add a line to the end of the Notes field of the BBDB record 
corresponding to the sender of this message.  If REPLACE is non-nil,
replace the existing notes entry (if any)."
  (interactive (list (if bbdb-readonly-p
			 (error "The Insidious Big Brother Database is read-only.")
			 (read-string "Comments: "))))
  (vm-follow-summary-cursor)
  (bbdb-annotate-notes (bbdb/vm-update-record t) string 'notes replace))


(defun bbdb/vm-edit-notes (&optional arg)
  "Edit the notes field or (with a prefix arg) a user-defined field
of the BBDB record corresponding to the sender of this message."
  (interactive "P")
  (vm-follow-summary-cursor)
  (let ((record (or (bbdb/vm-update-record t) (error ""))))
    (bbdb-display-records (list record))
    (if arg
	(bbdb-record-edit-property record nil t)
      (bbdb-record-edit-notes record t))))

;;;###autoload
(defun bbdb/vm-show-sender ()
  "Display the contents of the BBDB for the sender of this message.
This buffer will be in bbdb-mode, with associated keybindings."
  (interactive)
  (vm-follow-summary-cursor)
  (let ((record (bbdb/vm-update-record t)))
    (if record
	(bbdb-display-records (list record))
	(error "unperson"))))


(defun bbdb/vm-pop-up-bbdb-buffer (&optional offer-to-create)
  "Make the *BBDB* buffer be displayed along with the VM window(s),
displaying the record corresponding to the sender of the current message."
  (bbdb-pop-up-bbdb-buffer
    (function (lambda (w)
      (let ((b (current-buffer)))
	(set-buffer (window-buffer w))
	(prog1 (eq major-mode 'vm-mode)
	  (set-buffer b))))))
  (let ((bbdb-gag-messages t)
	(bbdb-use-pop-up nil)
	(bbdb-electric-p nil))
    (let ((record (bbdb/vm-update-record offer-to-create))
	  (bbdb-elided-display (bbdb-pop-up-elided-display))
	  (b (current-buffer)))
      (bbdb-display-records (if record (list record) nil))
      (set-buffer b)
      record)))

(defun bbdb/vm-record-and-change-message-pointer (old new)
  (prog1 (bbdb-orig-vm-record-and-change-message-pointer old new)
    (bbdb/vm-update-record nil)))


;; By Alastair Burt <burt@dfki.uni-kl.de>
;; vm 5.40 and newer support a new summary format, %U<letter>, to call
;; a user-provided function.  Use "%-17.17UB" instead of "%-17.17F" to
;; have your VM summary buffers display BBDB's idea of the sender's full
;; name instead of the name (or lack thereof) in the message itself.

(defun vm-summary-function-B (m &optional to-p)
  "Given a VM message returns the BBDB name of the sender.
Respects vm-summary-uninteresting-senders."
  (if (and vm-summary-uninteresting-senders (not to-p))
      (let ((case-fold-search nil))
	(if (string-match vm-summary-uninteresting-senders (vm-su-from m))
	    (concat vm-summary-uninteresting-senders-arrow
		    (vm-summary-function-B m t))
	  (or (bbdb/vm-alternate-full-name  (vm-su-from m))
	      (vm-su-full-name m))))
    (or (bbdb/vm-alternate-full-name (if to-p (vm-su-to m) (vm-su-from m)))
	(if to-p (vm-su-to-names m) (vm-su-full-name m)))))

(defun bbdb/vm-alternate-full-name (address)
  (if address 
      (let ((entry (bbdb-search-simple nil
				       (if (and address bbdb-canonicalize-net-hook)
					   (bbdb-canonicalize-address address)
					 address))))
	(if entry
	    (or (bbdb-record-getprop entry 'mail-name)
		(bbdb-record-name entry))))))


;;;###autoload
(defun bbdb-insinuate-vm ()
  "Call this function to hook BBDB into VM."
  (cond ((boundp 'vm-select-message-hook) ; VM 5.36+
		 (add-hook 'vm-select-message-hook 'bbdb/vm-update-record))
		((boundp 'vm-show-message-hook)	; VM 5.32.L+
		 (add-hook 'vm-show-message-hook 'bbdb/vm-update-record))
		(t
		 (error "vm versions older than 5.36 no longer supported")

		 ;; Hack on to vm-record-and-change-message-pointer, since VM 5.32
		 ;; doesn't have vm-show-message-hook.
		 (or (fboundp 'bbdb-orig-vm-record-and-change-message-pointer)
			 (fset 'bbdb-orig-vm-record-and-change-message-pointer
				   (symbol-function 'vm-record-and-change-message-pointer)))
		 (fset 'vm-record-and-change-message-pointer
			   (symbol-function 'bbdb/vm-record-and-change-message-pointer))
		 ))
  (define-key vm-mode-map ":" 'bbdb/vm-show-sender)
  (define-key vm-mode-map ";" 'bbdb/vm-edit-notes)
  ;; VM used to inherit from mail-mode-map, so bbdb-insinuate-sendmail
  ;; did this.  Kyle, you loser.
  (if (boundp 'vm-mail-mode-map)
      (define-key vm-mail-mode-map "\M-\t" 'bbdb-complete-name)))

(provide 'bbdb-vm)
