;;; pushbullet.el --- Emacs client for the PushBullet Android app

;; Copyright (C) 2013  Abhishek L

;; Author: Abhishek L <abhishekl.2006@gmail.com>
;; URL: http://www.github.com/theanalyst/pushbullet.el
;; Version: 0.2.0
;; Package-Requires:((grapnel "0.5.2") (json "1.3"))
;; Keywords: convenience

;; This file is not a part of GNU Emacs

;;; License:

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 3
;; of the License, or (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;; Pushbullet is an android app that handles notifications. Luckily
;; there's an API which we can use to push stuff from your favourite
;; editor to your phone
;;
;; At the moment this uses `grapnel' library for http requests. This
;; is just an experiment, any comments and suggestions are more than
;; welcome. Customize the variable `pb/api-key' in the group
;; `pushbullet' to match your api-key. At present calling
;; `pb/send-region' interactively with a selection will send that
;; selection with the user specified title to your android app
;; and calling `pb/send-buffer' will send the whole contents of buffer
;; to the app

;;; History:

;; 0.1.0 - Initial release.

;; 0.2.0 - Adding support for shared devices

;;; Code:

(require 'grapnel)
(require 'json)

(defgroup pushbullet nil
  "An emacs pushbullet client"
  :prefix "pb/"
  :group 'applications)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Customization Variables ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defcustom pb/api-key nil
  "API Key for your pushbullet account"
  :type 'string
  :group 'pushbullet)

(defvar pb/device-id-list nil
  "Alist of device_ids.")

(defvar pb/api-url "https://api.pushbullet.com/api/")

(defun pb/get-devices ()
  "Get the devices available for pushing data"
  (let ((grapnel-options (concat "-u " pb/api-key ":")))
    (grapnel-retrieve-url
     (concat pb/api-url "devices")
     `((success . pb/fill-device-id-list)
       (failure . pb/failure-callback)
       (error .  pb/error-callback))
   "GET")))

(defun pb/push-item (devices text type title)
  "Pushes the item"
  (dolist (device_id devices)
    (let ((grapnel-options (concat "-u " pb/api-key ": ")))
      (grapnel-retrieve-url
       (concat pb/api-url "pushes")
	  `((success . (lambda (res hdrs) (message "success!")))
	    (failure . pb/failure-callback)
	    (error .  pb/error-callback))
	  "POST"
	    nil
	    `(("device_iden" . ,device_id)
	      ("type" . ,type)
	      ("title" . ,title)
	      ("body" . ,text))))))

(defun pb/error-callback (res hdrs)
  (message "curl error! %s" hdrs))

(defun pb/failure-callback (msg &optional res hdrs)
  (message "request failure! %s" hdrs))

(defun pb/json-extract (key tag devices-json)
  "Extracts the tag and key from a given json"
  (let* ((json-object-type 'alist)
	 (pb-json-response (json-read-from-string devices-json)))
    (mapcar (lambda (x) (cdr (assoc key  x)))
	    (cdr (assoc tag pb-json-response)))))

(defun pb/device-ids-from-json (json)
  `(("id" . ,(pb/json-extract 'id 'devices json))
    ("shared" . ,(pb/json-extract 'id 'shared json))))

(defun pb/fill-device-id-list (res hdrs)
  (setq pb/device-id-list (pb/device-ids-from-json res)))

(defun pb/ensure-device-ids ()
  "Checks if pb/device-id-list is set, else set it"
  (unless pb/device-id-list
    (pb/get-devices)))

;;;###autoload
(defun pushbullet (start end all? title)
  "Pushes the selection as a note. Title defaults to buffer-name
   but is accepted as a user input. If there is no selection, the
   entire buffer is sent. With a prefix arg send to shared
   devices as well "
  (interactive
   (let ((push-title
	  (read-string "Title for the push :" (buffer-name) nil (buffer-name))))
     (if mark-active
	 (list (region-beginning) (region-end) current-prefix-arg push-title)
       (list (point-min) (point-max) current-prefix-arg push-title))))
  (let ((selection (buffer-substring-no-properties start end))
	(devices  (progn
		    (pb/ensure-device-ids)
		    (if all?
			(mapcar 'cdr pb/device-id-list)
		      (cdr (assoc 'devices pb/device-id-list))))))
    (unless (= (length selection) 0)
      (pb/push-item devices selection "note" title))))

(provide 'pushbullet)

;;; pushbullet.el ends here
