#!/usr/bin/env bash
# Clean any polluted config, then run pmbootstrap init with a native ext4 work
# path and preset answers for samsung-on7xelte.
cd "$HOME"
export PATH="$HOME/.local/bin:$PATH"
rm -f ~/.config/pmbootstrap*.cfg
# answers: work-path, pmaports(default), channel(default), vendor, device, then
# blanks take defaults for kernel/username/UI/etc.
printf '%s\n' \
  "$HOME/pmos" "" "" "samsung" "on7xelte" "" "" "" "" "" "" "" "" "" "" "" "" "" "" "" \
  | pmbootstrap init 2>&1 | tail -70
