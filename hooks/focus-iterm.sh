#!/bin/bash
# Brings iTerm2 to the front on the session whose id is $1.
# Called when you click a banner sent by notify.sh.
osascript <<EOF
tell application "iTerm2"
  activate
  repeat with w in windows
    repeat with t in tabs of w
      repeat with s in sessions of t
        if id of s is "$1" then
          select w
          select t
          select s
        end if
      end repeat
    end repeat
  end repeat
end tell
EOF
