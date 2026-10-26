#!/bin/sh
# HOME in the container is /home/gr, so a "~/.guided-review/..." path in config.json (a key file,
# say) would miss GR_HOME, which is mounted at its host path.
if [ -n "$GR_HOME" ] && [ "$GR_HOME" != "$HOME/.guided-review" ]; then
  ln -sfn "$GR_HOME" "$HOME/.guided-review"
fi
exec node /app/bin/gr.js "$@"
