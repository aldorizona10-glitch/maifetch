;;; maifetch.el --- MaiTea fetch tool for Emacs -*- lexical-binding: t; -*-

;; Author: maifetch contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: games, tools

;;; Commentary:

;; A small MaiTea fetch client that can run inside Emacs with `M-x maifetch`
;; or from a shell with:
;;
;;   emacs --batch -l maifetch.el --funcall maifetch-batch -- --access-token TOKEN

;;; Code:

(require 'cl-lib)
(require 'json)
(require 'url)
(require 'url-http)
(require 'subr-x)

(defgroup maifetch nil
  "Fetch and display MaiTea profile information in Emacs."
  :group 'applications)

(defcustom maifetch-base-url "https://maitea.app"
  "Base URL for MaiTea API requests."
  :type 'string
  :group 'maifetch)

(defcustom maifetch-config-file
  (expand-file-name "maifetch.json" user-emacs-directory)
  "Default JSON config file."
  :type 'file
  :group 'maifetch)

(defcustom maifetch-score-count 4
  "Default number of recent scores to display."
  :type 'integer
  :group 'maifetch)

(defcustom maifetch-logo-size 20
  "Default logo size.  Zero or negative values disable logo display."
  :type 'integer
  :group 'maifetch)

(defcustom maifetch-access-token nil
  "MaiTea access token.  Prefer config, env vars, or CLI args over this."
  :type '(choice (const nil) string)
  :group 'maifetch)

(defvar maifetch-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "g") #'maifetch-refresh)
    map)
  "Keymap for `maifetch-mode'.")

(define-derived-mode maifetch-mode special-mode "maifetch"
  "Major mode for rendered MaiTea profile output.")

(defun maifetch--json-object-type ()
  "Return the JSON object representation used by maifetch."
  'alist)

(defun maifetch--read-json-file (file)
  "Read FILE as JSON alist.
Return nil when FILE does not exist."
  (when (and file (file-readable-p file))
    (with-temp-buffer
      (insert-file-contents file)
      (let ((json-object-type (maifetch--json-object-type))
            (json-array-type 'list)
            (json-key-type 'symbol)
            (json-false nil))
        (json-read)))))

(defun maifetch--alist-get-any (keys alist)
  "Return the first present value for KEYS in ALIST."
  (catch 'found
    (dolist (key keys)
      (let ((cell (assq key alist)))
        (when cell
          (throw 'found (cdr cell)))))
    nil))

(defun maifetch--env (names)
  "Return the first non-empty environment value from NAMES."
  (catch 'found
    (dolist (name names)
      (let ((value (getenv name)))
        (when (and value (not (string-empty-p value)))
          (throw 'found value))))
    nil))

(defun maifetch--parse-int (value fallback)
  "Parse VALUE as an integer or return FALLBACK."
  (cond
   ((integerp value) value)
   ((numberp value) (truncate value))
   ((and (stringp value) (string-match-p "\\`-?[0-9]+\\'" value))
    (string-to-number value))
   (t fallback)))

(defun maifetch--split-cli (args)
  "Split ARGS at the first -- separator."
  (let ((seen-separator nil)
        before after)
    (dolist (arg args)
      (if seen-separator
          (push arg after)
        (if (string= arg "--")
            (setq seen-separator t)
          (push arg before))))
    (if seen-separator
        (nreverse after)
      (nreverse before))))

(defun maifetch--parse-cli (args)
  "Parse command-line ARGS into an alist."
  (let (out)
    (while args
      (let ((arg (pop args)))
        (cond
         ((member arg '("--access-token" "--token" "-a" "-t"))
          (push (cons 'accessToken (pop args)) out))
         ((member arg '("--score-count" "-s"))
          (push (cons 'scoreCount (pop args)) out))
         ((member arg '("--logo-size" "-l"))
          (push (cons 'logoSize (pop args)) out))
         ((member arg '("--config-file" "-c"))
          (push (cons 'configFile (pop args)) out))
         ((member arg '("--help" "-h"))
          (push (cons 'help t) out))
         (t
          (push (cons 'unknown arg) out)))))
    (nreverse out)))

(defun maifetch-help ()
  "Return command-line help text."
  (string-join
   '("maifetch.el - MaiTea fetch tool for Emacs"
     ""
     "Usage:"
     "  emacs --batch -l maifetch.el --funcall maifetch-batch -- [options]"
     "  M-x maifetch"
     ""
     "Options:"
     "  -a, -t, --access-token, --token TOKEN"
     "  -s, --score-count COUNT       recent scores to display, max 12"
     "  -l, --logo-size SIZE          zero or negative disables logo placeholder"
     "  -c, --config-file FILE        JSON config file"
     "  -h, --help"
     ""
     "Precedence: CLI > MAITEA_* env vars > MAIFETCH_* env aliases > config file > defaults.")
   "\n"))

(defun maifetch-load-config (&optional args)
  "Load maifetch config using ARGS.
Precedence is CLI > env vars > config file > defaults."
  (let* ((cli (maifetch--parse-cli (or args nil)))
         (config-file (or (maifetch--alist-get-any '(configFile) cli)
                          (maifetch--env '("MAITEA_CONFIG_FILE" "MAIFETCH_CONFIG_FILE"))
                          maifetch-config-file))
         (file-config (or (maifetch--read-json-file config-file) nil))
         (access-token (or (maifetch--alist-get-any '(accessToken access-token token) cli)
                           (maifetch--env '("MAITEA_TOKEN" "MAIFETCH_TOKEN"))
                           (maifetch--alist-get-any '(accessToken access-token token) file-config)
                           maifetch-access-token))
         (score-count (maifetch--parse-int
                       (or (maifetch--alist-get-any '(scoreCount score-count) cli)
                           (maifetch--env '("MAITEA_SCORE_COUNT" "MAIFETCH_SCORE_COUNT"))
                           (maifetch--alist-get-any '(scoreCount score-count) file-config))
                       maifetch-score-count))
         (logo-size (maifetch--parse-int
                     (or (maifetch--alist-get-any '(logoSize logo-size) cli)
                         (maifetch--env '("MAITEA_LOGO_SIZE" "MAIFETCH_LOGO_SIZE"))
                         (maifetch--alist-get-any '(logoSize logo-size) file-config))
                     maifetch-logo-size)))
    (when (maifetch--alist-get-any '(help) cli)
      (user-error "%s" (maifetch-help)))
    (unless (and access-token (not (string-empty-p access-token)))
      (user-error "access token is required"))
    (when (> score-count 12)
      (user-error "score count cannot be higher than 12"))
    `((access-token . ,access-token)
      (score-count . ,score-count)
      (logo-size . ,logo-size)
      (config-file . ,config-file))))

(defun maifetch--json-read-buffer ()
  "Read JSON from the current buffer after HTTP headers."
  (goto-char (point-min))
  (when (re-search-forward "\n\n" nil t)
    (let ((json-object-type (maifetch--json-object-type))
          (json-array-type 'list)
          (json-key-type 'symbol)
          (json-false nil))
      (json-read))))

(defun maifetch-api-get (path access-token)
  "Fetch PATH from MaiTea using ACCESS-TOKEN and return parsed JSON."
  (let ((url-request-method "GET")
        (url-request-extra-headers
         `(("Authorization" . ,(concat "Bearer " access-token))
           ("Content-Type" . "application/json")
           ("Accept" . "application/json"))))
    (with-current-buffer (url-retrieve-synchronously
                          (concat (string-remove-suffix "/" maifetch-base-url) path)
                          t t 30)
      (unwind-protect
          (maifetch--json-read-buffer)
        (kill-buffer (current-buffer))))))

(defun maifetch-get-profiles (access-token)
  "Return profiles for ACCESS-TOKEN."
  (alist-get 'data (maifetch-api-get "/api/v1/profiles" access-token)))

(defun maifetch-get-paged (path access-token)
  "Return a paginated API response for PATH and ACCESS-TOKEN."
  (maifetch-api-get path access-token))

(defun maifetch-page-data (page)
  "Return PAGE data."
  (alist-get 'data page))

(defun maifetch-page-next-url (page)
  "Return PAGE next URL."
  (alist-get 'next (alist-get 'links page)))

(defun maifetch-page-prev-url (page)
  "Return PAGE previous URL."
  (alist-get 'prev (alist-get 'links page)))

(defun maifetch-get-plays (access-token)
  "Return recent plays page for ACCESS-TOKEN."
  (maifetch-get-paged "/api/v1/plays" access-token))

(defun maifetch-get-all-plays (access-token)
  "Return all plays page for ACCESS-TOKEN."
  (maifetch-get-paged "/api/v1/plays/all" access-token))

(defun maifetch-get-best-scores (access-token)
  "Return best scores page for ACCESS-TOKEN."
  (maifetch-get-paged "/api/v1/scores" access-token))

(defun maifetch-get-all-best-scores (access-token)
  "Return all best scores page for ACCESS-TOKEN."
  (maifetch-get-paged "/api/v1/scores/all" access-token))

(defun maifetch--fullwidth-to-ascii (string)
  "Convert common full-width ASCII characters in STRING."
  (apply #'string
         (mapcar (lambda (char)
                   (if (and (>= char #xff01) (<= char #xff5e))
                       (- char #xfee0)
                     char))
                 string)))

(defun maifetch--ansi-fg (text r g b)
  "Return TEXT colored with RGB foreground R G B."
  (format "\x1b[38;2;%d;%d;%dm%s\x1b[0m" r g b text))

(defun maifetch--accent (text)
  "Return TEXT with maifetch accent color."
  (maifetch--ansi-fg text 72 184 200))

(defun maifetch-difficulty-string (difficulty)
  "Return display label for DIFFICULTY."
  (pcase difficulty
    ("easy" (maifetch--ansi-fg "Easy" 69 174 255))
    ("basic" (maifetch--ansi-fg "Basic" 111 212 61))
    ("advanced" (maifetch--ansi-fg "Advanced" 248 183 9))
    ("expert" (maifetch--ansi-fg "Expert" 255 46 66))
    ("master" (maifetch--ansi-fg "Master" 171 140 233))
    ((or "remaster" "re:master") (maifetch--ansi-fg "Re:Master" 207 114 237))
    ("utage" (maifetch--ansi-fg "Utage" 255 68 1))
    (_ difficulty)))

(defun maifetch-rank-string (rank)
  "Return display label for RANK."
  (pcase rank
    ("SSS+" (concat (maifetch--ansi-fg "S" 255 200 54)
                    (maifetch--ansi-fg "S" 225 38 165)
                    (maifetch--ansi-fg "S" 73 64 233)
                    (maifetch--ansi-fg "+" 21 203 148)))
    ("SSS" (concat (maifetch--ansi-fg "S" 255 200 54)
                   (maifetch--ansi-fg "S" 232 39 148)
                   (maifetch--ansi-fg "S" 18 195 144)))
    ((or "SS+" "SS") (maifetch--ansi-fg rank 248 200 75))
    ((or "S+" "S") (maifetch--ansi-fg rank 248 200 75))
    ((or "AAA" "AA" "A") (maifetch--ansi-fg rank 23 163 255))
    (_ rank)))

(defun maifetch--play-line (play)
  "Return formatted lines for PLAY."
  (let* ((song (alist-get 'song play))
         (song-name (or (alist-get 'en (alist-get 'name song)) "Unknown song"))
         (difficulty (alist-get 'value (alist-get 'difficulty_level play)))
         (score (or (alist-get 'score_formatted play) "0"))
         (achievement (or (alist-get 'achievement_formatted play) "0"))
         (rank (or (alist-get 'rank play) ""))
         (full-combo (or (alist-get 'full_combo_label play) "")))
    (list
     (format "  %s  %s" song-name (maifetch-difficulty-string difficulty))
     (format "  %s %s%% %s %s"
             score achievement (maifetch-rank-string rank) full-combo)
     "")))

(defun maifetch-render (profile plays &optional score-count logo-size)
  "Render PROFILE and PLAYS with SCORE-COUNT and LOGO-SIZE."
  (let* ((count (min (or score-count maifetch-score-count) (length plays)))
         (name (maifetch--fullwidth-to-ascii (or (alist-get 'name profile) "Unknown")))
         (rating (/ (float (or (alist-get 'rating profile) 0)) 100.0))
         (highest (/ (float (or (alist-get 'rating_highest profile) 0)) 100.0))
         (play-stats (alist-get 'play_stats profile))
         (lines (list
                 (maifetch--accent name)
                 (make-string (length name) ?-)
                 (format "%s: %s" (maifetch--accent "ID") (or (alist-get 'id profile) 0))
                 (format "%s: %.2f / %.2f" (maifetch--accent "Rating") rating highest)
                 (format "%s: %s" (maifetch--accent "Level") (or (alist-get 'level profile) 0))
                 (format "%s: %s" (maifetch--accent "Total Credits") (or (alist-get 'total play-stats) 0))
                 (format "%s:" (maifetch--accent "Recent Scores")))))
    (dotimes (index count)
      (setq lines (append lines (maifetch--play-line (nth index plays)))))
    (when (and logo-size (> logo-size 0))
      (setq lines (append (list (format "[MaiTea icon placeholder: %dx%d]" (* logo-size 2) logo-size)
                                "")
                          lines)))
    (string-join lines "\n")))

(defun maifetch-refresh ()
  "Refresh the current maifetch buffer."
  (interactive)
  (maifetch))

;;;###autoload
(defun maifetch (&optional args)
  "Render MaiTea profile in an Emacs buffer.
Optional ARGS follows the command-line parser."
  (interactive)
  (let* ((config (maifetch-load-config args))
         (token (alist-get 'access-token config))
         (score-count (alist-get 'score-count config))
         (logo-size (alist-get 'logo-size config))
         (profiles (maifetch-get-profiles token)))
    (unless profiles
      (user-error "No profiles found"))
    (let* ((plays (maifetch-page-data (maifetch-get-plays token)))
           (output (maifetch-render (car profiles) plays score-count logo-size)))
      (with-current-buffer (get-buffer-create "*maifetch*")
        (let ((inhibit-read-only t))
          (erase-buffer)
          (insert output)
          (goto-char (point-min))
          (maifetch-mode))
        (pop-to-buffer (current-buffer))))))

(defun maifetch-batch ()
  "Batch entrypoint for shell use."
  (let ((args (maifetch--split-cli command-line-args-left)))
    (if (member "--help" args)
        (princ (concat (maifetch-help) "\n"))
      (let* ((config (maifetch-load-config args))
             (token (alist-get 'access-token config))
             (score-count (alist-get 'score-count config))
             (logo-size (alist-get 'logo-size config))
             (profiles (maifetch-get-profiles token)))
        (unless profiles
          (user-error "No profiles found"))
        (princ (maifetch-render
                (car profiles)
                (maifetch-page-data (maifetch-get-plays token))
                score-count
                logo-size))
        (princ "\n")))))

(provide 'maifetch)

;;; maifetch.el ends here
