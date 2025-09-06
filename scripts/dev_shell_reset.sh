#!/usr/bin/env bash
# Fast reset for interactive zsh shells after strict-mode mishaps
if [ -n "${ZSH_VERSION-}" ]; then
  # relax nounset and patch prompt vars
  print -r -- "Resetting zsh: disabling nounset and patching PROMPT vars…"
  exec zsh -c 'set +u; unsetopt nounset 2>/dev/null || true; typeset -g RPROMPT="${RPROMPT-}"; typeset -g PROMPT="${PROMPT-}"; exec zsh -l'
else
  echo "This reset is intended for zsh shells; nothing to do."
fi

