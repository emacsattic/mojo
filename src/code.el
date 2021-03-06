(define-minor-mode mojo-mode
  "Toggle Mojo mode.
     With no argument, this command toggles the mode.
     Non-null prefix argument turns on the mode.
     Null prefix argument turns off the mode.
     
     When Mojo mode is enabled various commands are enabled to
     aid the development of Mojo applications.

     Make sure you customize the variables
     \\[mojo-project-directory], \\[mojo-sdk-directory] and
     \\[mojo-build-directory].

     Keybindings are:

      * C-c C-c a     -- \\[mojo-switch-to-assistant]
      * C-c C-c i     -- \\[mojo-switch-to-appinfo]
      * C-c C-c I     -- \\[mojo-switch-to-index]
      * C-c C-c n     -- \\[mojo-switch-to-next-view]
      * C-c C-c s     -- \\[mojo-switch-to-sources]
      * C-c C-c S     -- \\[mojo-switch-to-stylesheet]
      * C-c C-c v     -- \\[mojo-switch-to-last-view]
      * C-c C-c SPC   -- \\[mojo-switch-file-dwim]
      * C-c C-c C-d   -- \\[mojo-target-device]
      * C-c C-c C-e   -- \\[mojo-emulate]
      * C-c C-c C-p   -- \\[mojo-package]
      * C-c C-c C-r   -- \\[mojo-package-install-and-inspect]
      * C-c C-c C-s   -- \\[mojo-generate-scene]
      * C-c C-c C-t   -- \\[mojo-toggle-target]

     See the source code mojo.el or the README file for a list of
     all of the interactive commands."
  ;; The initial value.
  :init-value nil
  ;; The indicator for the mode line.
  :lighter "-Mojo"
  ;; The minor mode bindings.
  :keymap
  '(("\C-c\C-ca" . mojo-switch-to-assistant)
    ("\C-c\C-ci" . mojo-switch-to-appinfo)
    ("\C-c\C-cI" . mojo-switch-to-index)
    ("\C-c\C-cn" . mojo-switch-to-next-view)
    ("\C-c\C-cs" . mojo-switch-to-sources)
    ("\C-c\C-cS" . mojo-switch-to-stylesheet)
    ("\C-c\C-cv" . mojo-switch-to-last-view)
    ("\C-c\C-c " . mojo-switch-file-dwim)
    ("\C-c\C-c\C-d" . mojo-target-device)
    ("\C-c\C-c\C-e" . mojo-emulate)
    ("\C-c\C-c\C-p" . mojo-package)
    ("\C-c\C-c\C-r" . mojo-package-install-and-inspect)
    ("\C-c\C-c\C-s" . mojo-generate-scene)
    ("\C-c\C-c\C-t" . mojo-toggle-target))
  :group 'mojo)

(defcustom mojo-sdk-version ""
  "Version of the SDK installed. Since 1.4.5, the PDK and SDK are installed 
at the same time, so there is only one var for both"
  :version "1.4.5.465")

(defcustom mojo-sdk-directory
  (case system-type
	((windows-nt) "c:/progra~1/palm/sdk")
	((darwin) "/opt/PalmSDK/Current")
	(t ""))
  "Path to where the mojo SDK is.

Note, using the old-school dos name of progra~1 was the only way i could make
this work."
  :type 'directory
  :group 'mojo)

(defcustom mojo-project-directory ""
  "Directory where all your Mojo projects are located."
  :type 'directory
  :group 'mojo)

(defcustom mojo-build-directory ""
  "Directory where built projects are saved."
  :type 'directory
  :group 'mojo)

;;* debug
(defcustom mojo-debug nil
  "Run Mojo in debug mode."
  :type 'boolean
  :group 'mojo)

;; Call this from your emacs config file with the modes you want to hook.
(defun mojo-setup-mode-hooks (&rest hooks)
  "Add `mojo-maybe-enable-minor-mode' to the specified mode hooks."
  (dolist (hook hooks)
    (add-hook hook 'mojo-maybe-enable-minor-mode)))

(defun mojo-maybe-enable-minor-mode ()
  "Enable `mojo-mode' when the current buffer belongs to a Mojo project."
  (when (mojo-project-p)
    (mojo-mode)))

;;* interactive generate
(defun mojo-generate (title directory)
  "Generate a new Mojo application in the `mojo-project-directory'.

TITLE is the name of the application.
DIRECTORY is the directory where the files are stored."
  ;;TODO handle existing directories (use --overwrite)
  (interactive "sTitle: \nsDirectory Name (inside of mojo-project-directory): \n")
  (let ((mojo-dir (expand-file-name (concat mojo-project-directory "/" directory))))
	(when (file-exists-p mojo-dir)
		  (error "Cannot mojo-generate onto an existing directory! (%s)" mojo-dir))
	(make-directory mojo-dir)
	(mojo-cmd "palm-generate" (list "-p" (format "\"{'title':'%s'}\"" title)
					mojo-dir))
	(find-file (concat mojo-dir "/appinfo.json"))))

;;* interactive
(defun mojo-generate-scene (name)
  "Generate a new Mojo scene for the current application.

NAME is the name of the scene."
  (interactive "sScene Name: \n")
  (let ((mojo-dir (mojo-root t)))
    (mojo-cmd "palm-generate" (list "-t" "new_scene"
				    "-p" (format "name=%s" name) mojo-dir))
    (find-file (format "%s/app/assistants/%s-assistant.js" mojo-dir name))
    (find-file (format "%s/app/views/%s/%s-scene.html" mojo-dir name name))))

;;* interactive 
(defun mojo-emulate ()
  "Launch the palm emulator."
  (interactive)
  (mojo-target-emulator) ;; target emulator from now on
  (unless (mojo-emulator-running-p)
    (mojo-cmd "palm-emulator" nil)))

;;* interactive 
(defun mojo-package ()
  "Package the current application into `MOJO-BUILD-DIRECTORY'."
  (interactive)
  (mojo-cmd "palm-package" (list "-o" (expand-file-name mojo-build-directory)
				 (mojo-root t))))

;;* interactive 
(defun mojo-install ()
  "Install the package named by `MOJO-PACKAGE-FILENAME'. The emulator is started if needed."
  (interactive)
  (mojo-ensure-emulator-is-running)
  (mojo-cmd-with-target "palm-install" (list (expand-file-name (mojo-read-package-filename))))
  (mojo-invalidate-app-cache))

;;* interactive 
(defun mojo-list ()
  "List all installed packages."
  (interactive)
  (mojo-ensure-emulator-is-running)
  (mojo-cmd-with-target "palm-install" (list "--list")))

;;* interactive 
(defun mojo-delete ()
  "Remove an application."
  (interactive)
  (mojo-ensure-emulator-is-running)
  (mojo-cmd-with-target "palm-install" (list "-r" (mojo-read-app-id)))
  (mojo-invalidate-app-cache))

(defun mojo-ensure-emulator-is-running ()
  "Launch the emulator unless it is already running."
  (if (string= "tcp" *mojo-target*)
      (progn
	(when (not (mojo-emulator-running-p))
	  (mojo-emulate)
	  (print "Launching the emulator, this will take a minute..."))
	(while (not (mojo-emulator-responsive-p))
	  (sleep-for 3))
	(print "Emulator has booted!"))
    (print "Connect your device if necessary.")))

;;* interactive 
(defun mojo-launch ()
  "Launch the current application in the emulator, and the emulator if necessary.."
  (interactive)
  (mojo-ensure-emulator-is-running)
  (mojo-cmd-with-target "palm-launch" (list (mojo-read-app-id))))

;;* interactive 
(defun mojo-close ()
  "Close an application."
  (interactive)
  (mojo-ensure-emulator-is-running)
  (mojo-cmd-with-target "palm-launch" (list "-c" (mojo-read-app-id))))

;;* interactive
(defun mojo-inspect ()
  "Run the DOM inspector on the current application."
  (interactive)
  (mojo-ensure-emulator-is-running)
  (mojo-set-log-level-for-debugging)
  (mojo-cmd-with-target "palm-launch" (list "-i" (mojo-read-app-id))))

;;* interactive
(defun mojo-list-emulator-images ()
  "Lists the emulator images"
  (interactive)
  (mojo-cmd "palm-emulator" (list "--list")))

;;* interactive
(defun mojo-hard-reset (image)
  "Perform a hard reset, clearing all data."
  (interactive "sImage name: \n")
  (if (string= "" image)
      (error "Run mojo-list-emulator-images to see what images are available")
    (mojo-cmd "palm-emulator" (list "--reset" image))))

(defun mojo-browse ()
  "Use `browse-url' to visit your application with Palm Host."
  (browse-url "http://localhost:8888"))


;;* interactive 
(defun mojo-package-install-and-inspect ()
  "Package, install, and launch the current application for inspection."
  (interactive)
  (mojo-package)
  (mojo-ensure-emulator-is-running)
  (mojo-cmd-with-target "palm-install" (list (expand-file-name (mojo-package-filename))))
  (mojo-cmd-with-target "palm-launch" (list "-i" (mojo-app-id))))

;;* interactive 
(defun mojo-package-install-and-launch ()
  "Package, install, and launch the current application."
  (interactive)
  (mojo-package)
  (mojo-ensure-emulator-is-running)
  (mojo-cmd-with-target "palm-install" (list (expand-file-name (mojo-package-filename))))
  (mojo-cmd-with-target "palm-launch" (list (mojo-app-id))))


;;* interactive
(defun mojo-target-device ()
  "Specify that Mojo commands should target a real device.

Sets `*mojo-target*' to \"usb\"."
  (interactive)
  (setq *mojo-target* "usb"))

;;* interactive
(defun mojo-target-emulator ()
  "Specify that Mojo commands should target a real device.

Sets `*mojo-target*' to \"tcp\"."
  (interactive)
  (setq *mojo-target* "tcp"))


;;* interactive
(defun mojo-toggle-target ()
  "Automatically change the target device from 'usb' to 'tcp' and vice versa."
  (interactive)
  (if (string= "usb" *mojo-target*)
      (mojo-target-emulator)
    (mojo-target-device)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Some support functions that grok the basics of a Mojo project. ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun mojo-parent-directory (path)
  "Get the parent directory, i.e. the head of a path by dropping the last component."
  (if (< (length path) 2)
      path
    (substring path 0 (- (length path)
			 (length (mojo-filename path))
			 1)))) ;; subtract one more for the trailing slash

(defun mojo-filename (path)
  "Get the filename from a path, i.e. the last component, or tail."
  (if (< (length path) 2)
      path
    (let ((start -2))
      (while (not (string= "/" (substring path start (+ start 1))))
	(setq start (- start 1)))
      (substring path (+ start 1)))))

(defvar *mojo-last-root* ""
  "Last Mojo root found by `MOJO-ROOT'.")

(defun mojo-root (&optional ask)
  "Find a Mojo project's root directory starting with `DEFAULT-DIRECTORY'.
   If ASK is non-nil and no root was found, ask the user for a directory."
  (let ((last-component (mojo-filename default-directory))
	(dir-prefix default-directory))
    ;; remove last path element until we find appinfo.json
    (while (and (not (file-exists-p (concat dir-prefix "/appinfo.json")))
		(not (< (length dir-prefix) 2)))
      (setq last-component (mojo-filename dir-prefix))
      (setq dir-prefix (mojo-parent-directory dir-prefix)))

    ;; If no Mojo root found, ask for a directory.
    (when (and ask (< (length dir-prefix) 2))
      (setq dir-prefix (mojo-read-root)))

    ;; Invalidate cached values when changing projects.
    (when (or (mojo-blank *mojo-last-root*)
	      (not (string= dir-prefix *mojo-last-root*)))
      (setq *mojo-last-root* dir-prefix)
      (setq *mojo-package-filename* nil)
      (setq *mojo-app-id* nil)
      (setq *mojo-appinfo* nil))

    dir-prefix))

;; foolproof enough? don't want false positives.
(defun mojo-project-p ()
  "Return T if the current buffer belongs to a Mojo project, otherwise NIL."
  (and (file-exists-p (concat (mojo-root) "/appinfo.json"))
       (file-exists-p (concat (mojo-root) "/sources.json"))
       (file-exists-p (concat (mojo-root) "/app"))
       (file-exists-p (concat (mojo-root) "/index.html"))))

(defun mojo-read-json-file (filename)
  "Parse the JSON in FILENAME and return the result."
  (save-excursion
    (let* ((origbuffer (current-buffer))
	   (path (concat (mojo-root) "/" filename))
	   (filebuffer (find-file-noselect path)))
      (set-buffer filebuffer)
      (let ((text (buffer-string)))
	(switch-to-buffer origbuffer)
        (json-read-from-string text)))))

(defun mojo-write-json-file (filename content)
  "Convert CONTENT to JSON and write to FILENAME in `mojo-root'."
  (save-excursion
    (let* ((origbuffer (current-buffer))
	   (path (concat (mojo-root) "/" filename))
	   (filebuffer (find-file-noselect path)))
      (set-buffer filebuffer)
      (erase-buffer)
      (insert (json-encode content) "\n")
      (save-buffer)
      (switch-to-buffer origbuffer))))

(defvar *mojo-appinfo* nil
  "Last structure read from appinfo.json.")

(defun mojo-appinfo ()
  "Get the contents of appinfo.json. Last read appinfo is cached."
  (when (mojo-project-p)
    (or *mojo-appinfo*
	(setq *mojo-appinfo* (mojo-read-json-file "appinfo.json")))))

(defun mojo-app-version ()
  "Parse the project version from appinfo.json."
  (when (mojo-project-p)
    (cdr (assoc 'version (mojo-appinfo)))))

(defun mojo-app-id ()
  "Parse the project id from appinfo.json."
  (when (mojo-project-p)
      (cdr (assoc 'id (mojo-appinfo)))))

(defun mojo-app-title ()
  "Parse the project title from appinfo.json."
  (when (mojo-project-p)
      (cdr (assoc 'title (mojo-appinfo)))))

(defun mojo-informal-app-id ()
  "Parse the project title from appinfo.json and remove all non alphanumeric characters."
  (let ((title (downcase (mojo-app-title))))
    (replace-regexp-in-string "[^a-z0-9]" "" title)))

(defun mojo-package-filename ()
  "Get the package filename for the specified application."
  (format "%s/%s_%s_all.ipk" (expand-file-name mojo-build-directory)
	  (mojo-app-id) (mojo-app-version)))


(defun mojo-framework-config ()
  "Get the contents of framework_config.json."
  (when (mojo-project-p)
    (and (file-exists-p (concat (mojo-root) "/framework_config.json"))
	 (mojo-read-json-file "framework_config.json"))))

(defun mojo-write-framework-config (config)
  "Set the contents of framework_config.json to the JSON representation of CONFIG."
  (when (mojo-project-p)
    (mojo-write-json-file "framework_config.json" config)))

(defun mojo-framework-config-value (key)
  "Retrieve a value from framework_config.json."
  (when (and (mojo-project-p)
	     (mojo-framework-config))
    (cdr (assoc key (mojo-framework-config)))))

(defun mojo-framework-config-boolean (key)
  "Retrieve the value of a boolean in framework_config.json."
  (string= t (mojo-framework-config-value key)))

;;* interactive
(defun mojo-debugging-enabled-p ()
  (interactive)
  "Determine if debugging is enabled for the current Mojo project."
  (print (mojo-framework-config-boolean 'debuggingEnabled)))

;;* interactive
(defun mojo-log-events-p ()
  (interactive)
  "Determine if event logging is enabled for the current Mojo project."
  (print (mojo-framework-config-boolean 'logEvents)))

;;* interactive
(defun mojo-timing-enabled-p ()
  (interactive)
  "Determine if timing is enabled for the current Mojo project."
  (print (mojo-framework-config-boolean 'timingEnabled)))

;;* interactive
(defun mojo-use-native-json-parser-p ()
  (interactive)
  "Determine if the native JSON parser is enabled for the current Mojo project."
  (print (mojo-framework-config-boolean 'useNativeJSONParser)))

;;* interactive
(defun mojo-log-level ()
  "The log level for the current Mojo project."
  (interactive)
  (when (and (mojo-project-p)
	     (mojo-framework-config))
    (print (cdr (assoc 'logLevel (mojo-framework-config))))))

;;* interactive
(defun mojo-escape-html-in-templates-p ()
  "Return T if HTML is escaped in templates, NIL otherwise."
  (interactive)
  (print (mojo-framework-config-boolean 'escapeHTMLInTemplates)))


(defun mojo-change-framework-config-value (key value)
  "Set the value for a key in framework_config.json."
  (interactive)
  (when (mojo-project-p)
    (let ((config (mojo-framework-config)))
      (unless config (setq config (list)))
      (setq config (assq-delete-all key config))
      (mojo-write-framework-config (cons (cons key (or value :json-false))
					 config)))))

;;* interactive
(defun mojo-set-debugging-enabled (enabled)
  "Enable debugging if ENABLED is t, or disable if it is nil or :json-false."
  (interactive "XEnable debugging? (t or nil) ")
  (mojo-change-framework-config-value 'debuggingEnabled enabled))

;;* interactive
(defun mojo-toggle-debugging ()
  "If debugging is enabled then disable it, and vice versa."
  (interactive)
  (mojo-change-framework-config-value 'debuggingEnabled (not (mojo-debugging-enabled-p))))

;;* interactive
(defun mojo-set-log-level (level)
  "Set the log level to the integer LEVEL.

Mojo.Log.LOG_LEVEL_INFO is 10
Mojo.Log.LOG_LEVEL_ERROR is 30"
  (interactive "nLog level: ")
  (mojo-change-framework-config-value 'logLevel level))

;;* interactive
(defun mojo-set-escape-html-in-templates (enabled)
  "Escape HTML if ENABLED is t, don't escape HTML if it is nil or :json-false."
  (interactive "XEscape HTML in templates? (t or nil) ")
  (mojo-change-framework-config-value 'escapeHTMLInTemplates enabled))

;;* interactive
(defun mojo-set-log-events (enabled)
  "Turn event logging on if ENABLED is t, or off if it is nil or :json-false."
  (interactive "XLog events? (t or nil) ")
  (mojo-change-framework-config-value 'debuggingEnabled enabled))

;;* interactive
(defun mojo-set-timing-enabled (enabled)
  "Enable timing if ENABLED is t, or disable timing if it is nil or :json-false."
  (interactive "XEnable timing? (t or nil) ")
  (mojo-change-framework-config-value 'timingEnabled enabled))

;;* interactive
(defun mojo-set-use-native-json-parser (enabled)
  "Use the native JSON parser if ENABLED is t, or not if it is nil or :json-false."
  (interactive "XUse native JSON parser? (t or nil) ")
  (mojo-change-framework-config-value 'useNativeJSONParser enabled))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; app listing and completion ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar *mojo-app-cache-filename* nil)
(defun mojo-app-cache-file (&optional force-reload)
  "Cache the list of applications in a temporary file.  Return the filename."
  (when (or force-reload
	  (not *mojo-app-cache-filename*))
    (setq *mojo-app-cache-filename* (make-temp-file "mojo-app-list-cache"))
    (save-excursion
      (let ((buffer (find-file-noselect *mojo-app-cache-filename*))
	    (apps (mojo-fetch-app-list)))
	(set-buffer buffer)
	(insert (mojo-string-join "\n" apps))
	(basic-save-buffer)
	(kill-buffer buffer))))
  *mojo-app-cache-filename*)

(defvar *mojo-app-id* nil
  "Most recently used application id.")

(defvar *mojo-package-filename* nil
  "Most recently used package file.")

(defvar *mojo-app-history* nil
  "List of the most recently used application ids.")

;; cache expires hourly by default
(defvar *mojo-app-cache-ttl* 3600
  "The minimum age of a stale cache file, in seconds.")

(defvar *mojo-package-history* nil
  "List of the most recently used package filenames.")

;; this is from rails-lib.el in the emacs-rails package
(defun mojo-string-join (separator strings)
  "Join all STRINGS using SEPARATOR."
  (mapconcat 'identity strings separator))

(defun mojo-blank (thing)
  "Return T if THING is nil or an empty string, otherwise nil."
  (or (null thing)
      (and (stringp thing)
           (= 0 (length thing)))))

(defun mojo-read-root ()
  "Get the path to a Mojo application, prompting with completion and history."
  (read-file-name "Mojo project: " (expand-file-name (concat mojo-project-directory "/"))))

(defun mojo-read-package-filename ()
  "Get the filename of a packaged application, prompting with completion and history.

The app id is stored in *mojo-package-filename* unless it was blank."
  (let* ((default (or *mojo-package-filename*
		      (mojo-package-filename)))
         (package (read-file-name (format "Package file (default: %s): " default)
				  (concat mojo-build-directory "/") default t)))
    (setq *mojo-package-filename* (mojo-filename package))
    (expand-file-name package)))

(defun mojo-read-app-id (&optional prompt)
  "Get the id of an existing application, prompting with completion and history.

The app id is stored in *mojo-app-id* unless it was blank."
  (let* ((default (or *mojo-app-id* (mojo-app-id)))
         (prompt (or prompt
		     (format "App id (default: %s): " default)))
         (app-id (completing-read prompt
				  (mojo-app-list t)
				  nil
				  t
				  nil
				  '*mojo-app-history*
				  default)))
    (when (mojo-blank app-id)
      (setq app-id (mojo-app-id)))
    (setq *mojo-app-id* app-id)
    app-id))

(defun mojo-app-list (&optional fetch-if-missing-or-stale)
  "Get a list of installed Mojo applications."
  (cond ((and (file-readable-p (mojo-app-cache-file))
              (not (mojo-app-cache-stale-p)))
         (save-excursion
           (let* ((buffer (find-file (mojo-app-cache-file)))
                  (apps (split-string (buffer-string))))
             (kill-buffer buffer)
             apps)))
        (fetch-if-missing-or-stale
         (mojo-app-cache-file t) ;; force reload
         (mojo-app-list)) ;; guaranteed cache hit this time
        (t nil)))

(defun mojo-fetch-app-list ()
  "Fetch a fresh list of all applications."
  (mojo-ensure-emulator-is-running)
  (let* ((raw-list (nthcdr 7 (split-string (mojo-cmd-to-string "palm-install" (list "--list")))))
	 (apps (list))
	 (appname-regex "^[^0-9][^.]+\\(\\.[^.]+\\)+$")
	 (item (pop raw-list)))
    (while item
	(if (string-match appname-regex item) ;; liberal regex for simplicity
	  (push item apps)
	(print (concat "discarding " item)))
	(setq item (pop raw-list)))
    (nreverse apps)))

(defun mojo-app-cache-stale-p ()
  "Non-nil if the cache in `MOJO-APP-CACHE-FILE' is more than *mojo-app-cache-ttl* seconds old.

If the cache file does not exist then it is considered stale."
  (or (null (file-exists-p (mojo-app-cache-file)))
      (let* ((now (float-time (current-time)))
             (last-mod (float-time (sixth (file-attributes
             (mojo-app-cache-file)))))
             (age (- now last-mod)))
        (> age *mojo-app-cache-ttl*))))

(defun mojo-invalidate-app-cache ()
  "Delete the app list cache."
  (delete-file (mojo-app-cache-file)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; switch to files easily  ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar *mojo-switch-suffixes*
  '(("-assistant.js" . mojo-switch-to-last-view)
    (".html"         . mojo-switch-to-next-view)
    (""              . mojo-switch-to-appinfo))
  "Suffixes of files that we can switch from and where to switch, with catch-all to appinfo.json by default.")

(defvar *mojo-last-visited-view* nil
  "Path of the last visited view file.")

;;* interactive
(defun mojo-switch-to-appinfo ()
  "Switch to appinfo.json."
  (interactive)
  (when (mojo-project-p)
    (find-file (concat (mojo-root) "/appinfo.json"))))

;;* interactive
(defun mojo-switch-to-index ()
  "Switch to index.html."
  (interactive)
  (when (mojo-project-p)
    (find-file (concat (mojo-root) "/index.html"))))

;;* interactive
(defun mojo-switch-to-sources ()
  "Switch to sources.json."
  (interactive)
  (when (mojo-project-p)
    (find-file (concat (mojo-root) "/sources.json"))))

;;* interactive
(defun mojo-switch-to-stylesheet ()
  "Switch to the main CSS stylesheet, or the first one."
  (interactive)
  (when (mojo-project-p)
    (let* ((stylesheet-dir (concat (mojo-root) "/stylesheets"))
	   (path (concat stylesheet-dir "/"
			 (mojo-informal-app-id) ".css")))
      (when (not (file-exists-p path))
	(setq path (car (mojo-filter-paths (directory-files stylesheet-dir t)))))
      (find-file path))))

(defun mojo-parent-directory-name (path)
  "The parent directory's basename."
  (mojo-filename (mojo-parent-directory path)))

(defun mojo-current-filename ()
  "Return the filename part of the current buffer's path."
  (mojo-filename (buffer-file-name)))

(defun mojo-buffer-is-assistant-p ()
  "Determine if the current buffer is a scene assistant."
  (string= "assistants" (mojo-parent-directory-name (buffer-file-name))))

(defun mojo-scene-name-from-assistant ()
  "The scene name of the assistant being edited."
    (and (mojo-buffer-is-assistant-p)
	 (substring (mojo-current-filename) 0 (- 0 (length "-assistant.js")))))

(defun mojo-path-is-view-p (path)
  "Determine if the given path is a Mojo view."
  (string= "views" (mojo-parent-directory-name (mojo-parent-directory path))))

(defun mojo-buffer-is-view-p ()
  "Determine if the current buffer is a view."
  (mojo-path-is-view-p (buffer-file-name)))

(defun mojo-buffer-is-main-view-p ()
  "Determine if the current buffer is the main view of a scene."
  (and (mojo-buffer-is-view-p)
       (string= (concat (mojo-scene-name-from-view) "-scene.html")
		(mojo-current-filename))))

(defun mojo-scene-name-from-view ()
  "The scene name of the view being edited."
    (and (mojo-buffer-is-view-p)
	 (mojo-parent-directory-name (buffer-file-name))))

;;* interactive
(defun mojo-switch-file-dwim ()
  "Attempt to intelligently find a related file and switch to it.

This does what I (sjs) mean by default, so change *mojo-switch-suffixes*
if you want different behaviour."
  (interactive)
  (let* ((path (buffer-file-name))
	 (suffixes (copy-list *mojo-switch-suffixes*))
	 (switch-function
	  (catch 'break
	    (dolist (pair suffixes nil)
	      (let ((suffix (car pair))
		    (function (cdr pair)))
		(when (string= suffix (substring path (- 0 (length suffix))))
		  (throw 'break function)))))))
    (when switch-function
      (call-interactively switch-function))))

(defun mojo-buffer-is-scene-file-p ()
  "Determine if the current buffer belongs to a Mojo scene."
  (or (mojo-buffer-is-view-p)
      (mojo-buffer-is-assistant-p)))

;;* interactive
(defun mojo-switch-to-main-view ()
  "Switch to the corresponding main view from an assistant or any other view in the scene."
  (interactive)
  (when (and (mojo-project-p) (mojo-buffer-is-scene-file-p))
    (let* ((scene-name (mojo-scene-name)))
      (setq *mojo-last-visited-view* (concat (mojo-root)
					     "/app/views/" scene-name "/"
					     scene-name "-scene.html")))
      (find-file *mojo-last-visited-view*)))

(defun mojo-visited-view-paths ()
  "Return a list of all visited view paths, most recently visited first."
  (mojo-filter-paths (mapcar (function buffer-file-name) (buffer-list))
		     (lambda (path) (or (null path) (not (mojo-path-is-view-p path))))))

;;* interactive
(defun mojo-switch-to-last-view ()
  "Switch to the last visited view from another view or assistant.

If there no view can be found then the action depends on the
current buffer.  From an assistant you are taken to the main
view, from the main view you go to the next view, and from any
other view you go to the main view.  Any other file is a no op."
  (interactive)
  (let* ((view-paths (mojo-visited-view-paths))
	 (last-view-path (if (string= (buffer-file-name) (car view-paths))
			   (cadr view-paths)
			 (car view-paths))))
    (when last-view-path (find-file last-view-path))))

(defun mojo-ignored-path-p (path)
  "Paths that we don't want to look at when walking directories."
  (let ((filename (mojo-filename path)))
    (or (null filename)
	(string= (substring filename 0 1) ".") ;; "." and ".." and hidden files
	(and (string= (substring filename 0 1) "#") ;; emacs recovery files
	     (string= (substring filename -1) "#")))))

(defun mojo-filter-paths (all-paths &optional filter)
  "Filter out unimportant paths from a list of paths."
  (let ((wanted-paths (list))
 	(filter (or filter 'mojo-ignored-path-p)))
    (dolist (path all-paths wanted-paths)
      (unless (funcall filter path)
	(setq wanted-paths (cons path wanted-paths))))
    (reverse wanted-paths)))

(defun mojo-index (elem list)
  "Return the position of ELEM in LIST."
  (catch 'break
    (let ((index 0))
      (dolist (path list index)
	(incf index)
	(when (string= path elem)
	  (throw 'break index))))))

(defun mojo-scene-name ()
  "Get the name of the current Mojo scene, or nil if not a scene file."
  (or (mojo-scene-name-from-view)
      (mojo-scene-name-from-assistant)))

;;* interactive
(defun mojo-switch-to-next-view ()
  "Switch to the next view in this scene, alphabetically.  Wrap around at the end."
  (interactive)
  (when (and (mojo-project-p) (mojo-buffer-is-scene-file-p))
    (let* ((scene-name (mojo-scene-name))
	   (view-dir (concat (mojo-root) "/app/views/" scene-name))
	   (view-files (mojo-filter-paths (directory-files view-dir t)))
	   (mojo-filter-paths (directory-files (concat (mojo-root) "/app/views/" scene-name) t))
	   (index (mojo-index (buffer-file-name) view-files))
	   (filename (nth (mod index (length view-files)) view-files)))
      (find-file filename))))

;;* interactive
(defun mojo-switch-to-assistant ()
  "Swtich to the corresponding assistant from a view."
  (interactive)
  (let ((scene-name (mojo-scene-name-from-view)))
    (when (and (mojo-project-p)
	       scene-name)
      (find-file (concat (mojo-root)
			 "/app/assistants/" scene-name "-assistant.js")))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;* lowlevel luna
(defun mojo-luna-send (url data)
  "Send something through luna.

Luna-send is a program to send things like incoming calls, GPS status, SMS,
etc.  to your emulator.

This is a low level Emacs interface to luna-send.
URL is the luna url, and DATA is the data."
  (mojo-cmd "luna-send" (list "-n" "1" url data)))

(defvar *mojo-target* "tcp"
  "Used to specify the target platform, \"usb\" for the device and \"tcp\"
for the emulator.  Deaults to \"tcp\".")

(defun mojo-emulator-running-p ()
  "Determine if the webOS emulator is running or not.

This command only works on Unix-like systems."
  (case system-type
    ((windows-nt) nil)
    (darwin (= 0 (shell-command (concat "ps x | fgrep '" mojo-sdk-version "' | fgrep -v fgrep >/dev/null 2>&1"))))
    (t (= 0 (shell-command "ps x | fgrep 'Palm SDK' | fgrep -v fgrep >/dev/null 2>&1")))))


(defun mojo-emulator-responsive-p ()
  "Determine if the webOS emulator is able to respond to commands yet.
(i.e. if it's done booting)."
(= 0 (shell-command (concat (mojo-path-to-cmd "palm-install") " -d tcp --list >/dev/null 2>&1"))))


(defun mojo-path-to-cmd (cmd)
  "Return the absolute path to a Mojo SDK command line program."
  (case system-type
    ((windows-nt) (concat mojo-sdk-directory "/bin/" cmd ".bat"))
    (t (concat mojo-sdk-directory "/bin/" cmd))))

(defun mojo-quote (string)
  "Wrap a string in double quotes.

Used to quote filenames sent to shell commands."
  (concat "\"" string "\""))

;;* lowlevel cmd
(defun mojo-cmd (cmd args)
  "General interface for running mojo-sdk commands.

CMD is the name of the command (without path or extension) to execute.
 Automagically shell quoted.
ARGS is a list of all arguments to the command.
 These arguments are NOT shell quoted."
  (let ((cmd (mojo-path-to-cmd cmd))
	(args (mojo-string-join " " (mapcar 'mojo-quote args))))
    (when mojo-debug (message "running %s with args %s " cmd args))
    (shell-command (concat cmd " " args))))

;;* lowlevel cmd
(defun mojo-cmd-with-target (cmd args &optional target)
  "General interface for running mojo-sdk commands that accept a target device.

CMD is the name of the command (without path or extension) to
 execute.  Automagically shell quoted.  ARGS is a list of all
 arguments to the command.  These arguments are NOT shell quoted.
 TARGET specifies the target device, \"tcp\" or \"usb\"."
  (let ((args (cons "-d" (cons (or target *mojo-target*) args))))
    (mojo-cmd cmd args)))

;;* lowlevel cmd
(defun mojo-cmd-to-string (cmd args &optional target)
  "General interface for running mojo-sdk commands and capturing the output
   to a string.

CMD is the name of the command (without path or extension) to execute.
 Automatically shell quoted.
ARGS is a list of all arguments to the command.
 These arguments are NOT shell quoted."
  (let ((cmd (mojo-path-to-cmd cmd))
	(args (concat "-d " (or target *mojo-target*) " "
		       (mojo-string-join " " args))))
    (if mojo-debug (message "running %s with args %s " cmd args))
    (shell-command-to-string (concat cmd " " args))))

(provide 'mojo)
