# org-roam-gev-text-graph-mode
uses graph-easy to generate org-roam graphs inside an emacs buffer

Firstly get [graph-easy](https://metacpan.org/pod/Graph::Easy) working, in Ubuntu and Debian this looks like this:
```
apt-get install libgraph-easy-perl
```
If you're installing by hand then you need to put it in your $PATH or set org-roam-gev-graph-easy-binary to point to it directly.

Then you can enable it with use-package
```
(use-package org-roam-gev-text-graph-mode
    :requires org-roam
    :config (org-roam-gev-text-graph-mode t))
```

Alternatively you can do it by hand with something like this:
```
(require 'org-roam-gev-text-graph-mode)
(org-roam-gev-text-graph-mode t)
```

After that you can just call "M-x org-roam-graph" or whatever keybind you've setup.
