;;; versor-selection.el -- versatile cursor
;;; Time-stamp: <2004-10-07 10:28:43 guest05>
;;
;; emacs-versor -- versatile cursors for GNUemacs
;;
;; Copyright (C) 2004  John C. G. Sturdy
;;
;; This file is part of emacs-versor.
;; 
;; emacs-versor is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2 of the License, or
;; (at your option) any later version.
;; 
;; emacs-versor is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;; 
;; You should have received a copy of the GNU General Public License
;; along with emacs-versor; if not, write to the Free Software
;; Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

(provide 'versor-selection)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; highlighting current selection ;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar versor:items (list 'not-yet-set)
  ;; what was this old value? see if it works ok without it!
  ;; (list (cons (cons nil nil) nil))
  "The current versor items.
There is a separate value of this variable for each buffer.
Each item is represented by an overlay.
There is always at least one item in this list, to avoid churning
overlays; if there is no current item, the top item has nil for its
buffer.")

(defvar versor:latest-items nil
  "The items list as it was at the start of the current command,
but converted from overlays to conses of start . end, as the overlays
get cancelled on the pre-command-hook versor:de-indicate-current-item,
which we use to make sure we go away quietly when the user wants to type
other emacs commands.")

(mapcar 'make-variable-buffer-local
	'(versor:items
	  versor:latest-items))

(defun versor:set-current-item (start end)
  "Set the START and END of the current item, and get rid of any extra parts."
  (mapcar 'delete-overlay (cdr versor:items))
  (rplacd versor:items nil)
  (let ((item (and versor:items
		   (car versor:items))))
    (if (and (overlayp item) (overlay-buffer item))
	(move-overlay item start end (current-buffer))
      (make-versor:overlay start end))))

(defun versor:current-item-valid ()
  "Return whether there is a valid current item."
  (let ((item (car versor:items)))
    (and (overlayp item)
	 (overlay-buffer item))))

(defun versor:get-current-item ()
  "Return (start . end) for the current item.
If there are multiple items, return only the first one."
  (cond
   ((versor:current-item-valid)
    (let ((olay (car versor:items)))
      (cons (overlay-start olay)
	    (overlay-end olay))))
   ((versor:valid-item-list-p versor:latest-items)
    (car versor:latest-items))
   (t
    (versor:invent-item))))

(defun versor:get-current-items ()
  "Return the current items."
  (let ((result
	 (cond 
	  ((versor:current-item-valid)
	   ;; (message "versor:get-current-items: current item valid")
	   versor:items)
	  ((versor:valid-item-list-p versor:latest-items)
	   ;; (message "versor:get-current-items: latest item valid")
	   versor:latest-items)
	  (t
	   ;; (message "versor:get-current-items: constructing item")
	   (let ((pair (versor:invent-item)))
	     (make-versor:overlay (car pair) (cdr pair))
	     versor:items
	     )))
	 ))
    (message "%S" result)
    result))

(defun versor:overlay-start (olay)
  "Return the start of OLAY.
OLAY may be an overlay, or a cons used to preserve data from a destroyed overlay."
  (if (consp olay)
      (car olay)
    (overlay-start olay)))

(defun versor:overlay-end (olay)
  "Return the end of OLAY.
OLAY may be an overlay, or a cons used to preserve data from a destroyed overlay."
  (if (consp olay)
      (cdr olay)
    (overlay-end olay)))

(defun versor:display-item-list (label il)
  "With LABEL, display IL.
Meant for debugging versor itself."
  (message label)
  (mapcar (lambda (item)
	    (let ((start (versor:overlay-start item))
		  (end (versor:overlay-end item)))
	      (if (< (- end start) 16)
		  (message "  %d..%d: %s" start end
			   (buffer-substring start end))
	      (message "  %d..%d: %s..%s" start end
		       (buffer-substring start (+ start 8))
		       (buffer-substring (- end 8) end)))))
	  il))

(defun versor:invent-item ()
  "Invent a versor item around the current point.
Meant to be used by things that require an item, when there is none.
Leaves point in a position compatible with what has just been returned."
  ;; (message "Using %S in inventing item" (versor:current-level))
  (let* ((end (progn (funcall (or (versor:get-action 'end-of-item)
				  (versor:get-action 'next))
			      1)
		     ;; (message "invented end") (sit-for 2)
		     (point)))
	 (start (progn (funcall (versor:get-action 'previous) 1)
		       ;; (message "invented start") (sit-for 2)
		       (point))))
    ;; (message "Invented item %d..%d" start end)
    (cons start end)))

(defun versor:valid-item-list-p (a)
  "Return whether A is a valid item list."
  (and (consp a)
       (let ((cara (car a)))
	 (or (and (consp cara)
		  (integerp (car cara))
		  (integerp (cdr cara)))
	     (and (overlayp cara)
		  (bufferp (overlay-buffer cara)))))))

(defun versor:item-overlay ()
  "The (primary) item indication overlay for this buffer."
  (car versor:items))

(defun make-versor:overlay (start end)
  "Make a versor overlay at START END.
If there is already a versor overlay for this buffer, reuse that.
You should normally call versor:set-current-item rather than this."
  (unless (overlayp (versor:item-overlay))
    (let ((overlay (make-overlay start end (current-buffer))))
      (setq versor:items (list overlay))
      (overlay-put overlay 'face
		   (if versor:use-face-attributes
		       'versor:item
		     'region)
		   )))
  (move-overlay (versor:item-overlay) start end (current-buffer)))

(defun versor:extra-overlay (start end)
  "Make an extra versor overlay between START and END."
  (let ((overlay (make-overlay start end (current-buffer))))
    (overlay-put overlay 'face
		 (if versor:use-face-attributes
		     'versor:item
		   'region))
    (rplacd versor:items
	    (cons overlay
		  (cdr versor:items)))))

(defun delete-versor:overlay ()
  "Delete the versor overlay for this buffer."
  ;; in fact, we just disconnect it from the buffer,
  ;; to avoid having to keep creating and destroying overlays
  (let ((overlay (versor:item-overlay)))
    (when (overlayp overlay)
      (delete-overlay overlay)))
  ;; get rid of any extras
  (when versor:items
    (mapcar 'delete-overlay (cdr versor:items))
    (rplacd versor:items nil)))

(defun versor:clear-current-item-indication ()
  "Intended to go at the start of each versor motion command.
It clears variables looked at by versor:indicate-current-item, which sets them
up for itself only if the command didn't set them for it."
  (setq versor:indication-known-valid nil)
  (delete-versor:overlay))

(defun versor:indicate-current-item ()
  "Make the current item distinctly visible.
This is intended to be called at the end of all versor commands.
See also the complementary function versor:de-indicate-current-item,
which goes on the pre-command-hook up, to make sure that versor gets out of the way
of ordinarily Emacs commands."

  (condition-case error-var
      (progn

	;; the command we have just run may have set these for us,
	;; if it knows in such a way that it can tell us much faster
	;; than we could work out for ourselves; they are cleared at
	;; the start of each command by
	;; versor:clear-current-item-indication, which, like us, is
	;; called by the as-versor:command macro

	(unless (versor:current-item-valid)
	  (versor:set-current-item (point) (versor:end-of-item-position)))

	(when versor:try-to-display-whole-item
	  (let* ((item (versor:get-current-item))
		 (end (cdr item)))
	    ;; try to get the whole item on-screen
	    (when (> end (window-end))
	      (let* ((start (car item))
		     (lines-needed (count-lines start end))
		     (lines-available (- (window-height (selected-window)) 2)))
		(if (<= lines-needed lines-available)
		    (recenter (/ (- lines-available lines-needed) 2))
		  (recenter 0)
		  (message "%d more lines of this item would not fit on screen" (- lines-needed lines-available 1)))))))

	;; re-do this because it somehow gets taken off from time to time
	(add-hook 'pre-command-hook 'versor:de-indicate-current-item))
    (error
     (progn
       ;; (message "Caught error %S in item indication" error-var)
       ;; (with-output-to-temp-buffer "*Backtrace for item indication*" (backtrace))
       (versor:de-indicate-current-item)
       ))))

(defun versor:de-indicate-current-item ()
  "Remove the current item marking.
Intended to go on pre-command-hook, to make sure that versor gets out
of the way of ordinarily Emacs commands. in case, however, the new
command is itself a versor command, we save the item marking as a list
of conses of start . end, in versor:latest-items."
  (unless (eq (car versor:items) 'not-yet-set)
    (setq versor:latest-items
	  (catch 'no-region
	    (mapcar 
	     (lambda (item)
	       (if (overlayp item)
		   (cons (overlay-start item) (overlay-end item))
		 (if (condition-case error
			 (progn
			   (region-beginning)
			   nil)
		       (error t))
		     (throw 'no-region nil)
		   (cons (region-beginning) (region-end)))))
	     versor:items)))
    ;; (versor:display-item-list (format "starting command %S" this-command) versor:latest-items)
    (delete-versor:overlay)))

(defun versor:set-item-indication (arg)
  "Set whether item indication is done.
Positive argument means on, negative or zero is off."
  (interactive "p")
  (if (> arg 0)
      (progn
	(message "Item indication turned on")
	(setq versor:indicate-items t)
	(add-hook 'pre-command-hook 'versor:de-indicate-current-item)
	(versor:indicate-current-item))
    (message "Item indication turned off")
    (setq versor:indicate-items nil)
    (versor:de-indicate-current-item)
    (remove-hook 'pre-command-hook 'versor:de-indicate-current-item)))

;;;; end of versor-selection.el
