;;; -*- Mode:Emacs-Lisp -*-

;;; This file is part of the Insidious Big Brother Database (aka BBDB),
;;; copyright (c) 1991, 1992, 1993 Jamie Zawinski <jwz@netscape.com>.
;;; Various additional functionality for the BBDB.  See bbdb.texinfo.

;;; The Insidious Big Brother Database is free software; you can redistribute
;;; it and/or modify it under the terms of the GNU General Public License as
;;; published by the Free Software Foundation; either version 2 or (at your
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

;;; This file lets you do stuff like
;;;
;;;	o  automatically update a "timestamp" field each time a record is 
;;;        modified
;;;	o  automatically add some string to the notes field(s) based on the
;;;	   contents of header fields of the current message
;;;	o  only automatically create entries when certain header fields
;;;	   are matched
;;;	o  don't automatically create entries when certain header fields
;;;	   are matched
;;;
;;; Read the docstrings; read the texinfo file.

;;
;; $Id: bbdb-hooks.el,v 1.55 1998/02/23 07:09:37 simmonmt Exp $
;;
;; $Log: bbdb-hooks.el,v $
;; Revision 1.55  1998/02/23 07:09:37  simmonmt
;; We use add-hook now
;;
;; Revision 1.54  1998/01/06 06:05:31  simmonmt
;; Added provide of bbdb-hooks.  Fixed custom specs (added cons type
;; instead of group where appropriate).  Replaced bbdb-time-string
;; function with bbdb-time-internal-format variable.
;;
;; Revision 1.53  1997/12/01 05:00:49  simmonmt
;; Customized, added sshteingold@cctrading.com's change to time-string
;; function to use a format string.
;;
;; Revision 1.52  1997/09/28 06:01:05  simmonmt
;; Fix to accomodate nil gnus-single-article-buffer
;;
;;

(require 'bbdb)

(defmacro the-v18-byte-compiler-sucks-wet-farts-from-dead-pigeons ()
  ;; no such thing as eval-when, no way to conditionally require something
  ;; at compile time (except this!! <evil laughter> )
  (condition-case () (require 'vm) (error nil))
  nil)
(defun Nukem-til-they-glow ()
  (the-v18-byte-compiler-sucks-wet-farts-from-dead-pigeons))

(defvar bbdb-time-internal-format "%Y-%m-%d"
  "The internal date format.")

(defun bbdb-timestamp-hook (record)
  "For use as a bbdb-change-hook; maintains a notes-field called `timestamp'
for the given record which contains the time when it was last modified.  If
there is such a field there already, it is changed, otherwise it is added."
  (bbdb-record-putprop record 'timestamp (format-time-string
					  bbdb-time-internal-format)))

(defun bbdb-creation-date-hook (record)
  "For use as a bbdb-create-hook; adds a notes-field called `creation-date'
which is the current time string."
  ;; hey buddy, we've known about your antics since the eighties...
  (bbdb-record-putprop record 'creation-date (format-time-string
					      bbdb-time-internal-format)))


;;; Determining whether to create a record based on the content of the 
;;; current message.

(defun bbdb-header-start ()
  "Returns a marker at the beginning of the header block of the current
message.  This will not necessarily be in the current buffer."
  (cond ((memq major-mode '(vm-mode vm-summary-mode))
	 (if vm-mail-buffer (set-buffer vm-mail-buffer))
	 (vm-start-of (car vm-message-pointer)))
	((memq major-mode '(rmail-mode rmail-summary-mode))
	 (if (and (boundp 'rmail-buffer) rmail-buffer)
	     (set-buffer rmail-buffer))
	 (point-min-marker))
	((memq major-mode
	       '(gnus-Group-mode gnus-Subject-mode gnus-Article-mode))
	 (set-buffer gnus-article-buffer)
	 (point-min-marker))
	;; MH-E clause added by knabe.
	((eq major-mode 'mh-folder-mode)
	 (mh-show)
	 (set-buffer mh-show-buffer)
	 (point-min-marker))
	(t (point-min-marker))
	))


(defun bbdb-extract-field-value (field-name)
  "Given the name of a field (like \"Subject\") this returns the value of
that field in the current message, or nil.  This works whether you're in
GNUS, Rmail, or VM.  This works on multi-line fields, but if more than
one field of the same name is present, only the last is returned.  It is
expected that the current buffer has a message in it, and (point) is at the
beginning of the message headers."
  ;; we can't special-case VM here to use its cache, because the cache has
  ;; divided real-names from addresses; the actual From: and Subject: fields
  ;; exist only in the message.
  (setq field-name (concat (regexp-quote field-name) "[ \t]*:[ \t]*"))
  (let (done)
    (while (not (or done
		    (looking-at "\n") ; we're at BOL
		    (eobp)))
      (if (looking-at field-name)
	  (progn
	    (goto-char (match-end 0))
	    (setq done (buffer-substring (point)
					 (progn (end-of-line) (point))))
	    (while (looking-at "\n[ \t]")
	      (setq done (concat done " "
			   (buffer-substring (match-end 0)
			     (progn (end-of-line 2) (point))))))))
      (forward-line 1))
    done))


(defcustom bbdb-ignore-most-messages-alist '()
  "*An alist describing which messages to automatically create BBDB
records for.  This only works if bbdb/news-auto-create-p or 
bbdb/mail-auto-create-p (or both) is 'bbdb-ignore-most-messages-hook.
The format of this alist is 
   (( HEADER-NAME . REGEXP ) ... )
for example,
   ((\"From\" . \"@.*\\.maximegalon\\.edu\")
    (\"Subject\" . \"time travel\"))
will cause BBDB entries to be made only for messages sent by people at 
Maximegalon U., or (that's *or*) people posting about time travel.

See also bbdb-ignore-some-messages-alist, which has the opposite effect."
  :group 'bbdb-noticing-records
  :type '(repeat (cons
		  (string :tag "Header name")
		  (regexp :tag "Regex to match on header value"))))


(defcustom bbdb-ignore-some-messages-alist '()
  "*An alist describing which messages *not* to automatically create
BBDB records for.  This only works if bbdb/news-auto-create-p or 
bbdb/mail-auto-create-p (or both) is 'bbdb-ignore-some-messages-hook.
The format of this alist is 
   (( HEADER-NAME . REGEXP ) ... )
for example,
   ((\"From\" . \"mailer-daemon\")
    (\"To\" . \"mailing-list-1\\\\|mailing-list-2\")
    (\"CC\" . \"mailing-list-1\\\\|mailing-list-2\"))
will cause BBDB entries to not be made for messages from any mailer daemon,
or messages sent to or CCed to either of two mailing lists.

See also bbdb-ignore-most-messages-alist, which has the opposite effect."
  :group 'bbdb-noticing-records
  :type '(repeat (cons
		  (string :tag "Header name")
		  (regexp :tag "Regex to match on header value"))))


(defun bbdb-ignore-most-messages-hook (&optional invert-sense)
  "For use as the value of bbdb/news-auto-create-p or bbdb/mail-auto-create-p.
This will automatically create BBDB entries for messages which match
the bbdb-ignore-some-messages-alist (which see) and *no* others."
  ;; don't need to optimize this to check the cache, because if
  ;; bbdb/*-update-record uses the cache, this won't be called.
  (let ((rest (if invert-sense
		  bbdb-ignore-some-messages-alist
		  bbdb-ignore-most-messages-alist))
	(case-fold-search t)
	(done nil)
	(b (current-buffer))
	(marker (bbdb-header-start))
	field regexp fieldval)
    (set-buffer (marker-buffer marker))
    (save-restriction
      (widen)
      (while (and rest (not done))
	(goto-char marker)
	(setq field (car (car rest))
	      regexp (cdr (car rest))
	      fieldval (bbdb-extract-field-value field))
	(if (and fieldval (string-match regexp fieldval))
	    (setq done t))
	(setq rest (cdr rest))))
    (set-buffer b)
    (if invert-sense
	(not done)
	done)))


(defun bbdb-ignore-some-messages-hook ()
  "For use as a bbdb/news-auto-create-hook or bbdb/mail-auto-create-hook.
This will automatically create BBDB entries for messages which do *not*
match the bbdb-ignore-some-messages-alist (which see)."
  (bbdb-ignore-most-messages-hook t))


;;; Automatically add to the notes field based on the current message.

(defcustom bbdb-auto-notes-alist '()
  "*An alist which lets you have certain pieces of text automatically added
to the BBDB record representing the sender of the current message based on
the subject or other header fields.  This only works if bbdb-notice-hook 
is 'bbdb-auto-notes-hook.  The format of this alist is 

   (( HEADER-NAME
       (REGEXP . STRING) ... )
      ... )
for example,
   ((\"To\" (\"-vm@\" . \"VM mailing list\"))
    (\"Subject\" (\"sprocket\" . \"mail about sprockets\")
               (\"you bonehead\" . \"called me a bonehead\")))

will cause the text \"VM mailing list\" to be added to the notes field of
the record corresponding to anyone you get mail from via one of the VM
mailing lists.  If, that is, bbdb/mail-auto-create-p is set such that the
record would have been created, or the record already existed.

The format of elements of this list may also be 
       (REGEXP FIELD-NAME STRING)
or
       (REGEXP FIELD-NAME STRING REPLACE-P)
instead of
       (REGEXP . STRING)

meaning add the given string to the named field.  The field-name may not
be name, address, phone, or net (builtin fields) but must be either ``notes,''
``company,'' or the name of a user-defined note-field. 
       (\"pattern\" . \"string to add\")
is equivalent to
       (\"pattern\" notes \"string to add\")

STRING can contain \\& or \\N escapes like in function
`replace-match'.  For example, to automatically add the contents of the
\"organization\" field of a message to the \"company\" field of a BBDB
record, you can use this:

        (\"Organization\" (\".*\" company \"\\\\&\"))

\(Note you need two \\ to get a single \\ into a lisp string literal.\)

If STRING is an integer N, the N'th matching subexpression is used, so
the above example could be written more efficiently as

        (\"Organization\" (\".*\" company 0))

If STRING is neither a string or an integer, it should be a function, which
will be called with the contents of the field.  The result of that function
call is used as the field value (the returned value must be a string.)

If REPLACE-P is t, the string replaces the old contents instead of
being appended to it.

If multiple clauses match the message, all of the corresponding strings
will be added.

This works for news as well.  You might want to arrange for this to have
a different value when in mail as when in news.

See also variables `bbdb-auto-notes-ignore' and `bbdb-auto-notes-ignore-all'."
  :group 'bbdb-noticing-records
  :type '(repeat (group
		  (string :tag "Header name")
		  (repeat (cons
			   (regexp :tag "Regexp to match on header value")
			   (string :tag "String for notes if regexp matches"))))))

(defcustom bbdb-auto-notes-ignore nil
  "Alist of headers and regexps to ignore in bbdb-auto-notes-hook.
Each element looks like

    (HEADER . REGEXP)

For example,

    (\"Organization\" . \"^Gatewayed from\\\\\|^Source only\")

would exclude the phony `Organization:' headers in GNU mailing-lists
gatewayed to gnu.* newsgroups.  Note that this exclusion applies only
to a single field, not to the entire message.  For that, use the variable
bbdb-auto-notes-ignore-all."
  :group 'bbdb-noticing-records
  :type '(repeat (cons
		  (string :tag "Header name")
		  (regexp :tag "Regexp to match on header value"))))

(defcustom bbdb-auto-notes-ignore-all nil
  "Alist of headers and regexps which cause the entire message to be ignored
in bbdb-auto-notes-hook.  Each element looks like

    (HEADER . REGEXP)

For example,

    (\"From\" . \"BLAT\\\\.COM\")

would exclude any notes recording for message coming from BLAT.COM. 
Note that this is different from `bbdb-auto-notes-ignore', which applies
only to a particular header field, rather than the entire message."
  :group 'bbdb-noticing-records
  :type '(repeat (cons
		  (string :tag "Header name")
		  (regexp :tag "Regexp to match on header value"))))


(defun bbdb-auto-notes-hook (record)
  "For use as a bbdb-notice-hook.  This might automatically add some text
to the notes field of the BBDB record corresponding to the current record
based on the header of the current message.  See the documentation for
the variables bbdb-auto-notes-alist and bbdb-auto-notes-ignore."
  ;; This could stand to be faster...
  ;; could optimize this to check the cache, and noop if this record is
  ;; cached for any other message, but that's probably not the right thing.
  (or bbdb-readonly-p
  (let ((rest bbdb-auto-notes-alist)
	ignore
	(ignore-all bbdb-auto-notes-ignore-all)
	(case-fold-search t)
	(b (current-buffer))
	(marker (bbdb-header-start))
	field pairs fieldval  ; do all bindings here for speed
	regexp string notes-field-name notes
	 replace-p replace-or-add-msg)
    (set-buffer (marker-buffer marker))
    (save-restriction
      (widen)
      (goto-char marker)
      (if (and (setq fieldval (bbdb-extract-field-value "From"))
	       (string-match (bbdb-user-mail-names) fieldval))
	  ;; Don't do anything if this message is from us.  Note that we have
	  ;; to look at the message instead of the record, because the record
	  ;; will be of the recipient of the message if it is from us.
	  nil
	;; check the ignore-all pattern
	(while (and ignore-all (not ignore))
	  (goto-char marker)
	  (setq field (car (car ignore-all))
		regexp (cdr (car ignore-all))
		fieldval (bbdb-extract-field-value field))
	  (if (and fieldval
		   (string-match regexp fieldval))
	      (setq ignore t)
	    (setq ignore-all (cdr ignore-all))))

	(if ignore  ; ignore-all matched
	    nil
	 (while rest ; while their still are clauses in the auto-notes alist
	  (goto-char marker)
	  (setq field (car (car rest))	; name of header, e.g., "Subject"
		pairs (cdr (car rest))	; (REGEXP . STRING) or
					; (REGEXP FIELD-NAME STRING) or
					; (REGEXP FIELD-NAME STRING REPLACE-P)
		fieldval (bbdb-extract-field-value field)) ; e.g., Subject line
	  (if fieldval
	      (while pairs
		(setq regexp (car (car pairs))
		      string (cdr (car pairs)))
		(if (consp string)	; not just the (REGEXP .STRING) format
		    (setq notes-field-name (car string)
			  replace-p (nth 2 string) ; perhaps nil
			  string (nth 1 string))
		  ;; else it's simple (REGEXP . STRING)
		  (setq notes-field-name 'notes
			replace-p nil))
		(setq notes (bbdb-record-getprop record notes-field-name))
		(let ((did-match
		       (and (string-match regexp fieldval)
			    ;; make sure it is not to be ignored
			    (let ((re (cdr (assoc field bbdb-auto-notes-ignore))))
			      (if re
				  (not (string-match re fieldval))
				t)))))
		  ;; An integer as STRING is an index into match-data: 
		  ;; A function as STRING calls the function on fieldval: 
		  (if did-match
		      (setq string
			    (cond ((integerp string) ; backward compat
				   (substring fieldval
					      (match-beginning string)
					      (match-end string)))
				  ((stringp string)
				   (bbdb-auto-expand-newtext fieldval string))
				  (t
				   (goto-char marker)
				   (let ((s (funcall string fieldval)))
				     (or (stringp s)
					 (null s)
					 (error "%s returned %s: not a string"
						string s))
				     s)))))
		  ;; need expanded version of STRING here:
		  (if (and did-match
			   string ; A function as STRING may return nil
			   (not (and notes
				     ;; check that STRING is not already
				     ;; present in the NOTES field
				     (string-match
				      (concat "\\(\\Sw\\|\\`\\)"
					      (regexp-quote string)
					      "\\(\\Sw\\|\\'\\)")
				      notes))))
		      (if replace-p
			  ;; replace old contents of field with STRING
			  (progn
			    (if (eq notes-field-name 'notes)
				(message "Replacing with note \"%s\"" string)
			      (message "Replacing field \"%s\" with \"%s\""
				       notes-field-name string))
			    (bbdb-record-putprop record notes-field-name
						 string)
			    (bbdb-maybe-update-display record))
			;; add STRING to old contents, don't replace 
			(if (eq notes-field-name 'notes)
			    (message "Adding note \"%s\"" string)
			  (message "Adding \"%s\" to field \"%s\""
				   string notes-field-name))
			(bbdb-annotate-notes record string notes-field-name))))
		(setq pairs (cdr pairs))))
	  (setq rest (cdr rest))))))
    (set-buffer b))))


(defun bbdb-auto-expand-newtext (string newtext)
  ;; Expand \& and \1..\9 (referring to STRING) in NEWTEXT.
  ;; Note that in Emacs 18 match data are clipped to current buffer
  ;; size...so the buffer had better not be smaller than STRING (arrrrggggh!!)
  (let ((pos 0)
	(len (length newtext))
	(expanded-newtext ""))
    (while (< pos len)
      (setq expanded-newtext
	    (concat expanded-newtext
		    (let ((c (aref newtext pos)))
		      (if (= ?\\ c)
			  (cond ((= ?\& (setq c (aref newtext
						      (setq pos (1+ pos)))))
				 (substring string
					    (match-beginning 0)
					    (match-end 0)))
				((and (>= c ?1) 
				      (<= c ?9))
				 ;; return empty string if N'th
				 ;; sub-regexp did not match:
				 (let ((n (- c ?0)))
				   (if (match-beginning n)
				       (substring string
						  (match-beginning n)
						  (match-end n))
				     "")))
				(t (char-to-string c)))
			(char-to-string c)))))
      (setq pos (1+ pos)))
    expanded-newtext))


;;; I use this as the value of bbdb-canonicalize-net-hook; it is provided
;;; as an example for you to customize.

(defcustom bbdb-canonical-hosts
  (mapconcat 'regexp-quote
	     '("cs.cmu.edu" "ri.cmu.edu" "edrc.cmu.edu" "andrew.cmu.edu"
	       "mcom.com" "netscape.com" "cenatls.cena.dgac.fr"
	       "cenaath.cena.dgac.fr" "irit.fr" "enseeiht.fr" "inria.fr"
	       "cs.uiuc.edu" "xemacs.org")
	     "\\|")
  "Certain sites have a single mail-host; for example, all mail originating
at hosts whose names end in \".cs.cmu.edu\" can (and probably should) be
addressed to \"user@cs.cmu.edu\" instead.  This variable lists other hosts
which behave the same way."
  :group 'bbdb
  :type '(regexp :tag "Regexp matching sites"))

(defmacro bbdb-match-substring (string match)
  (list 'substring string
	(list 'match-beginning match) (list 'match-end match)))

(defun sample-bbdb-canonicalize-net-hook (addr)
  (cond
   ;;
   ;; rewrite mail-drop hosts.
   ;;
   ((string-match
     (concat "\\`\\([^@%!]+@\\).*\\.\\(" bbdb-canonical-hosts "\\)\\'")
     addr)
    (concat (bbdb-match-substring addr 1) (bbdb-match-substring addr 2)))
   ;;
   ;; Here at Lucid, our workstation names sometimes get into our email
   ;; addresses in the form "jwz%thalidomide@lucid.com" (instead of simply
   ;; "jwz@lucid.com").  This removes the workstation name.
   ;;
   ((string-match "\\`\\([^@%!]+\\)%[^@%!.]+@\\(lucid\\.com\\)\\'" addr)
    (concat (bbdb-match-substring addr 1) "@" (bbdb-match-substring addr 2)))
   ;;
   ;; Another way that our local mailer is misconfigured: sometimes addresses
   ;; which should look like "user@some.outside.host" end up looking like
   ;; "user%some.outside.host" or even "user%some.outside.host@lucid.com"
   ;; instead.  This rule rewrites it into the original form.
   ;;
   ((string-match "\\`\\([^@%]+\\)%\\([^@%!]+\\)\\(@lucid\\.com\\)?\\'" addr)
    (concat (bbdb-match-substring addr 1) "@" (bbdb-match-substring addr 2)))
   ;;
   ;; Sometimes I see addresses like "foobar.com!user@foobar.com".
   ;; That's totally redundant, so this rewrites it as "user@foobar.com".
   ;;
   ((string-match "\\`\\([^@%!]+\\)!\\([^@%!]+[@%]\\1\\)\\'" addr)
    (bbdb-match-substring addr 2))
   ;;
   ;; Sometimes I see addresses like "foobar.com!user".  Turn it around.
   ;;
   ((string-match "\\`\\([^@%!.]+\\.[^@%!]+\\)!\\([^@%]+\\)\\'" addr)
    (concat (bbdb-match-substring addr 2) "@" (bbdb-match-substring addr 1)))
   ;;
   ;; The mailer at hplb.hpl.hp.com tends to puke all over addresses which
   ;; pass through mailing lists which are maintained there: it turns normal
   ;; addresses like "user@foo.com" into "user%foo.com@hplb.hpl.hp.com".
   ;; This reverses it.  (I actually could have combined this rule with
   ;; the similar lucid.com rule above, but then the regexp would have been
   ;; more than 80 characters long...)
   ;;
   ((string-match "\\`\\([^@!]+\\)%\\([^@%!]+\\)@hplb\\.hpl\\.hp\\.com\\'"
		  addr)
    (concat (bbdb-match-substring addr 1) "@" (bbdb-match-substring addr 2)))
   ;;
   ;; Another local mail-configuration botch: sometimes mail shows up
   ;; with addresses like "user@workstation", where "workstation" is a
   ;; local machine name.  That should really be "user" or "user@netscape.com".
   ;; (I'm told this one is due to a bug in SunOS 4.1.1 sendmail.)
   ;;
   ((string-match "\\`\\([^@%!]+\\)[@%][^@%!.]+\\'" addr)
    (bbdb-match-substring addr 1))
   ;;
   ;; Sometimes I see addrs like "foo%somewhere%uunet.uu.net@somewhere.else".
   ;; This is silly, because I know that I can send mail to uunet directly.
   ;;
   ((string-match ".%uunet\\.uu\\.net@[^@%!]+\\'" addr)
    (concat (substring addr 0 (+ (match-beginning 0) 1)) "@UUNET.UU.NET"))
   ;;
   ;; Otherwise, leave it as it is.  Returning a string EQ to the one passed
   ;; in tells BBDB that we're done.
   ;;
   (t addr)))


;;; Here's another approach; sometimes one gets mail from foo@bar.baz.com,
;;; and then later gets mail from foo@baz.com.  At this point, one would
;;; like to delete the bar.baz.com address, since the baz.com address is
;;; obviously superior.  See also var `bbdb-canonicalize-redundant-nets-p'.
;;;
;;; Turn this on with
;;;   (add-hook 'bbdb-change-hook 'bbdb-delete-redundant-nets)

(defun bbdb-delete-redundant-nets (record)
  "Deletes redundant network addresses.
For use as a value of `bbdb-change-hook'.  See `bbdb-net-redundant-p'."
  (let* ((nets (bbdb-record-net record))
	 (rest nets)
	 net new redundant)
    (while rest
      (setq net (car rest))
      (if (bbdb-net-redundant-p net nets)
	  (setq redundant (cons net redundant))
	(setq new (cons net new)))
      (setq rest (cdr rest)))
    (cond (redundant
	   (message "Deleting redundant nets %s..."
		    (mapconcat 'identity (nreverse redundant) ", "))
	   (setq new (nreverse new))
	   (bbdb-record-set-net record new)
	   t))))

(provide 'bbdb-hooks)
