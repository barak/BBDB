;;; -*- Mode:Emacs-Lisp -*-

;;; This file is an addition to the Insidious Big Brother Database
;;; (aka BBDB), copyright (c) 1991, 1992 Jamie Zawinski
;;; <jwz@netscape.com>.
;;; 
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


;;; This file was written by Ivan Vazquez <ivan@haldane.bu.edu> 

;; $Date: 1998/04/11 07:21:39 $ by $Author: simmonmt $
;; $Revision: 1.55 $
;;
;; $Log: bbdb-ftp.el,v $
;; Revision 1.55  1998/04/11 07:21:39  simmonmt
;; Colin Rafferty's patch adding autoload cookies back
;;
;; Revision 1.54  1998/02/23 07:00:18  simmonmt
;; Intro rewrite to say that EFS is also OK as a prereq
;;
;; Revision 1.53  1998/01/06 04:52:15  simmonmt
;; Customized variables (into utilities-ftp group).  Added provide.
;;
;; Revision 1.52  1997/09/28 05:59:18  simmonmt
;; Added check for EFS (there must be a better way that what I did, but I
;; really don't want to be reduced to checking version strings.
;;

;;; This file adds the ability to define ftp-sites in a BBDB, much the same
;;; way one adds a regular person's name to the BBDB.  It also defines the
;;; bbdb-ftp command which allows you to ftp a site that is in a bbdb-record.
;;; You must have either EFS or ange-ftp in order to use this code.  Ange-ftp
;;; is available at archive.cis.ohio-state.edu in the
;;; /pub/gnu/emacs/elisp-archive/packages directory.  EFS ships with XEmacs.

;;; Note that Ftp Site BBDB entries differ from regular entries by the
;;; fact that the Name Field must have the ftp site preceeded by the
;;; bbdb-ftp-site-name-designator-prefix.  This defaults to "Ftp Site:" 
;;; BBDB Ftp Site entries also have two new fields added, the
;;; ftp-dir slot, and the ftp-user slot.  These are added to the notes
;;; alist part of the bbdb-records, the original bbdb-record structure
;;; remains untouched.

;;; The following user-level commands are defined for use:
;;;

;;; bbdb-ftp - Use ange-ftp to open an ftp-connection to a BBDB
;;;            record's name.  If this command is executed from the
;;;            *BBDB* buffer, ftp the site of the record at point;
;;;            otherwise, it prompts for an ftp-site. 

;;; bbdb-create-ftp-site -
;;;            Add a new ftp-site entry to the bbdb database; prompts
;;;            for all relevant info using the echo area, inserts the
;;;            new record in the db, sorted alphabetically.

;;; The package can be installed by compiling and adding the following
;;; two lines to your .emacs.

;;; (autoload 'bbdb-ftp                 "bbdb-ftp"  "Ftp BBDB Package" t)
;;; (autoload 'bbdb-create-ftp-site     "bbdb-ftp"  "Ftp BBDB Package" t)

(require 'bbdb)

;; There must be a better way
(if (featurep 'efs-cu)
    (require 'efs)
    (require 'ange-ftp))

(defcustom bbdb-default-ftp-user "anonymous"
  "*The default login to use when ftp-ing."
  :group 'bbdb-utilities-ftp
  :type 'string)

(defcustom bbdb-default-ftp-dir "/"
  "*The default directory to open when ftp-ing."
  :group 'bbdb-utilities-ftp
  :type 'string)

(defcustom bbdb-ftp-site-name-designator-prefix "Ftp Site: "
  "*The prefix that all ftp sites in the bbdb will have in their name field."
  :group 'bbdb-utilities-ftp
  :type 'string)

(defmacro defun-bbdb-raw-notes-accessor (slot)
  "Expands into an accessor function for slots in the notes alist."
  (let ((fn-name (intern (concat "bbdb-record-" (symbol-name slot)))))
    (list 'defun fn-name (list 'record)
	  (list 'cdr 
		(list 'assoc (list 'quote slot)
		      (list 'bbdb-record-raw-notes 'record))))))

(defun-bbdb-raw-notes-accessor ftp-dir) 
(defun-bbdb-raw-notes-accessor ftp-user)

(defun bbdb-record-ftp-site (record)
  "Acessor Function. Returns the ftp-site field of the BBDB record or nil."
  (let* ((name (bbdb-record-name record))
	 (ftp-pfx-regexp (concat bbdb-ftp-site-name-designator-prefix " *"))
	 (ftp-site 
	  (and (string-match ftp-pfx-regexp name) 
	       (substring name (match-end 0)))))
    ftp-site))

(defun remove-leading-whitespace (string)
  "Remove any spaces or tabs from only the start of the string."
  (let ((space-char-code (string-to-char " "))
	(tab-char-code   ?\t)
	(index 0))
    (if string
	(progn 
	  (while (or (char-equal (elt string index) space-char-code)
		     (char-equal (elt string index) tab-char-code))
	    (setq index (+ index 1)))
	  (substring string index))
      nil)))

;;;###autoload
(defun bbdb-ftp (bbdb-record)
  "Use ange-ftp to open an ftp-connection to a BBDB record's name.
If this command is executed from the *BBDB* buffer, ftp the site of
the record at point; otherwise, it prompts for an ftp-site.
\\<bbdb-mode-map>"
  (interactive (list (if (string= bbdb-buffer-name (buffer-name))
			 (bbdb-current-record)
		       (let (r (p "BBDB Ftp: "))
			 (while (not r)
			   (setq r (bbdb-completing-read-record p))
			   (if (not r) (ding))
			   (setq p "Not in the BBDB!  Ftp: "))
			 r))))
  (if (not (consp bbdb-record)) (setq bbdb-record (list bbdb-record)))
  (while bbdb-record
    (bbdb-ftp-internal (car bbdb-record))
    (setq bbdb-record (cdr bbdb-record))))

(defun bbdb-ftp-internal (bbdb-record)
  (let* ((site (or (bbdb-record-ftp-site bbdb-record) ""))
		 (dir  (or (bbdb-record-ftp-dir bbdb-record) bbdb-default-ftp-dir))
		 (user (or (bbdb-record-ftp-user bbdb-record) bbdb-default-ftp-user))
		 (file-string (concat "/" user "@" site ":" dir )))
	(if bbdb-inside-electric-display
		(bbdb-electric-throw-to-execute (list 'bbdb-ftp-internal bbdb-record)))
    (cond (site
		   (find-file-other-window file-string))
		  (t
		   (error
			"Not an ftp site.  Check bbdb-ftp-site-name-designator-prefix")))))

(defun bbdb-read-new-ftp-site-record ()
  "Prompt for and return a completely new bbdb-record that is
specifically an ftp site entry.  Doesn't insert it in to the database
or update the hashtables, but does insure that there will not be name
collisions."
  (bbdb-records) ; make sure database is loaded
  (if bbdb-readonly-p (error "The Insidious Big Brother Database is read-only."))
  (let (site)
    (bbdb-error-retry
     (progn
       (setq site (bbdb-read-string "Ftp Site: "))
       (setq site (concat bbdb-ftp-site-name-designator-prefix site))
       (if (bbdb-gethash (downcase site))
	    (error "%s is already in the database" site))))
    (let* ((dir  (bbdb-read-string "Ftp Directory: "
				   bbdb-default-ftp-dir))
	   (user  (bbdb-read-string "Ftp Username: "
				    bbdb-default-ftp-user))
	   (company (bbdb-read-string "Company: "))
	   (notes (bbdb-read-string "Additional Comments: "))
	   (names  (bbdb-divide-name site))
	   (firstname (car names))
	   (lastname (nth 1 names)))
      (if (string= user bbdb-default-ftp-user) (setq user nil))
      (if (string= company "") (setq company nil))
      (if (or (string= dir bbdb-default-ftp-dir) (string= dir ""))
	  (setq dir nil))
      (if (string= notes "")   (setq notes nil))

      (let ((record
	     (vector firstname lastname nil company nil nil nil 
		     (append 
		      (if notes (list (cons 'notes notes)) nil)
		      (if dir   (list (cons 'ftp-dir dir)) nil)
		      (if user  (list (cons 'ftp-user user)) nil))
		     (make-vector bbdb-cache-length nil))))
	record))))
   
;;;###autoload
(defun bbdb-create-ftp-site (record)
  "Add a new ftp-site entry to the bbdb database; prompts for all relevant info
using the echo area, inserts the new record in the db, sorted alphabetically."
  (interactive (list (bbdb-read-new-ftp-site-record)))
  (bbdb-invoke-hook 'bbdb-create-hook record)
  (bbdb-change-record record t)
  (bbdb-display-records (list record)))

(provide 'bbdb-ftp)
