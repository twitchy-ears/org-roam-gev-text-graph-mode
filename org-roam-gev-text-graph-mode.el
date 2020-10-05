;;; org-roam-gev-text-graph.el --- uses graph-easy to generate org-roam graphs inside an emacs buffer

;; Copyright 2020- Twitchy Ears

;; Author: Twitchy Ears https://github.com/twitchy-ears/
;; URL: https://github.com/twitchy-ears/
;; Version: 0.1
;; Package-Requires ((emacs "25") (org-roam "1.2.1"))
;; Keywords: org-roam graph

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.

;;; History
;;
;; 2020-10-05 - initial version

;;; Commentary:
;;
;; Install graph-easy, in Ubuntu and Debian this looks like:
;; apt-get install libgraph-easy-perl
;;
;; See also:
;; https://metacpan.org/pod/Graph::Easy
;;
;;
;; Then:
;; (use-package org-roam-gev-text-graph-mode
;;  :requires org-roam
;;  :config (org-roam-gev-text-graph-mode))


(defvar org-roam-gev-text-graph-buffername "*org-roam-text-graph-view*"
  "The buffer that will contain the output, be aware this will get frequently mangled and overwritten")

(defvar org-roam-gev-make-graph-linkable t
  "If true will rewrite the output and attempt to regex in [[file:/path/to/file][title]] style org-link links")

(defvar org-roam-gev-graph-easy-binary "graph-easy"
  "The graph-easy binary, if its not in your $PATH specify the full path to it")

(defun org-roam-gev-label-file-extract (graphfile)
  (let (accumulator)
    (with-temp-buffer
      (insert-file-contents graphfile)
      (goto-char (point-min))

      ;; Search for all the file descriptions with labels and build the accumulator alist
      ;; The structure is an alist of (<label> . <file>)
      (while (re-search-forward "^[[:space:]]*\"\\(.+?\\)\" \\[label=\"\\(.+?\\)\"" nil t)
          (push (cons (match-string 2) (match-string 1)) accumulator)))
    
    accumulator))

(defun org-roam-gev-buffer-link-rewriter (buffername label-to-file)
  (save-current-buffer
    (set-buffer buffername)
    (goto-char (point-min))

    ;; Search forward for the middle line of graph-easy's output, the
    ;; boxes look like:
    ;;
    ;;  | label-here |
    ;;
    ;; If we find one then see if we have a file for it in
    ;; label-to-file and if so write it back in.
    (while (re-search-forward "|\\([[:space:]]+\\)\\(.+?\\)\\([[:space:]]+\\)|" nil t)
      (let ((file (cdr (assoc (match-string 2) label-to-file))))
        (if file
            ;; FIXME replace the | pipe characters with unicode broken
            ;; bars because otherwise having a pipe seems to break the
            ;; org-link [[]] format for some of them but not all of
            ;; them.  This seems to fix it for all of them however.
            ;; Unclear why this is.
            (replace-match (format "¦\\1\[\[file:%s\]\[\\2\]\]\\3¦" file)))))))

(defun org-roam-gev-graph-easy-viewer (graphfile)
  "Open a buffer showing the org-roam graph parsed through graph-easy"
  ;; (interactive)

  ;; Create the buffer and/or blank it
  (get-buffer-create org-roam-gev-text-graph-buffername)
  (with-current-buffer org-roam-gev-text-graph-buffername
    (erase-buffer))

  ;; Run the graph-easy binary over the file to generate the text
  ;; output Really this should use :filter but ... also I'm not
  ;; wanting to touch that right now so instead I'm using a backtick
  ;; interpolation hack to include the ,graphfile variable inside the
  ;; :sentinel lambda.  Yes I know that this is not the right thing to
  ;; do.
  (make-process
   :name org-roam-gev-text-graph-buffername
   :buffer org-roam-gev-text-graph-buffername
   :command `(,org-roam-gev-graph-easy-binary ,graphfile)
   :sentinel (when callback
               `(lambda (process _event)
                  (when (= 0 (process-exit-status process))
                    (progn
                      
                      ;; Rewrite the buffer links if required, do this
                      ;; after generation to avoid messing up alignment
                      ;; FIXME: Note that this is using ,graphfile -
                      ;; all of this should be in an output :filter
                      (if org-roam-gev-make-graph-linkable
                          (org-roam-gev-buffer-link-rewriter org-roam-gev-text-graph-buffername
                                                             (org-roam-gev-label-file-extract ,graphfile)))
                      
                      ;; Jump the user focus to the buffer
                      (switch-to-buffer org-roam-gev-text-graph-buffername)
                      
                      ;; Back to the start and set the mode to org-mode to ensure links and things work
                      (goto-char (point-min))
                      (with-current-buffer org-roam-gev-text-graph-buffername
                        (org-mode))))))))

(defun org-roam-gev-graph--build (&optional node-query callback)
  "Generate a graph showing the relations between nodes in NODE-QUERY.
Execute CALLBACK when process exits successfully.
CALLBACK is passed the graph file as its sole argument.

This is not the original but an advice replacement that allows someone to parse the dot files"
  (let* ((node-query (or node-query
                         `[:select [file title] :from titles
                                   ,@(org-roam-graph--expand-matcher 'file t)
                                   :group :by file]))
         
         (graph (org-roam-graph--dot node-query))
         (temp-dot   (make-temp-file "graph." nil ".dot" graph)))
    (funcall callback temp-dot)))


(define-minor-mode org-roam-gev-text-graph-mode
  "When enabled will override the org-roam-graph-viewer and advice around org-roam-graph--build.

Uses the graph-easy command which relies on the Graph::Easy Perl
module, parses the org-roam dot output and by default will
attempt to rewrite the output to include org style links for each
node."
  nil
  nil
  nil
  :global t
  (if org-roam-gev-text-graph-mode
      (progn
        (setq org-roam-gev-original-graph-viewer-func org-roam-graph-viewer)
        (setq org-roam-graph-viewer (lambda (graphfile)
                                      (org-roam-gev-graph-easy-viewer graphfile)))
        
        (advice-add 'org-roam-graph--build :override #'org-roam-gev-graph--build))
    (progn
      (if org-roam-gev-original-graph-viewer-func
          (setq org-roam-graph-viewer org-roam-gev-original-graph-viewer-func))      
      (advice-remove 'org-roam-graph--build #'org-roam-gev-graph--build))))


(provide 'org-roam-gev-text-graph-mode)
