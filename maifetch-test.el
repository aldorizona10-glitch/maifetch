;;; maifetch-test.el --- Tests for maifetch -*- lexical-binding: t; -*-

(require 'ert)
(require 'maifetch)

(ert-deftest maifetch-config-cli-overrides-env-and-file ()
  (let* ((file (make-temp-file "maifetch" nil ".json"
                               "{\"accessToken\":\"file-token\",\"scoreCount\":2,\"logoSize\":3}"))
         (process-environment (copy-sequence process-environment)))
    (setenv "MAITEA_TOKEN" "env-token")
    (setenv "MAITEA_SCORE_COUNT" "4")
    (let ((config (maifetch-load-config
                   (list "--config-file" file
                         "--access-token" "cli-token"
                         "--score-count" "5"
                         "--logo-size" "0"))))
      (should (equal (alist-get 'access-token config) "cli-token"))
      (should (= (alist-get 'score-count config) 5))
      (should (= (alist-get 'logo-size config) 0)))))

(ert-deftest maifetch-config-rejects-too-many-scores ()
  (should-error
   (maifetch-load-config (list "--access-token" "token" "--score-count" "13"))))

(ert-deftest maifetch-fullwidth-normalization ()
  (should (equal (maifetch--fullwidth-to-ascii "ＡＢＣ１２３") "ABC123")))

(ert-deftest maifetch-render-includes-profile-and-score ()
  (let* ((profile '((id . 123)
                    (name . "Ｔｅｓｔ")
                    (rating . 1234)
                    (rating_highest . 1567)
                    (level . 9)
                    (play_stats . ((total . 42)))))
         (play '((song . ((name . ((en . "Song")))))
                 (difficulty_level . ((value . "expert")))
                 (score_formatted . "1,000,000")
                 (achievement_formatted . "100.0000")
                 (rank . "SSS+")
                 (full_combo_label . "FC")))
         (output (maifetch-render profile (list play) 1 0)))
    (should (string-match-p "Test" output))
    (should (string-match-p "ID" output))
    (should (string-match-p "Song" output))
    (should (string-match-p "1,000,000" output))))

(provide 'maifetch-test)

;;; maifetch-test.el ends here
