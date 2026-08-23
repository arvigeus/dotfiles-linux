# Module library

This directory contains the supported helper API for scripts below `modules/`.
Modules run independently inside the candidate root and source the helpers they
need through `$SETUP_ROOT/lib/`.

Installation and rebuild implementation details live in `installer/`; they are
not part of the module API.
