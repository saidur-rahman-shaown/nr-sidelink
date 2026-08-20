#!/usr/bin/env bash
# PreToolUse: deterministic enforcement of the normative-package discipline.
# Instructions drift over a long session; this does not.
input=$(cat)
eval "$(printf '%s' "$input" | python3 -c '
import json,sys,shlex
d=json.load(sys.stdin).get("tool_input",{})
p=d.get("file_path","")
c=d.get("new_string","") or d.get("content","")
print("F=%s" % shlex.quote(p))
print("C=%s" % shlex.quote(c))
' 2>/dev/null)"

# Normative packages: spec-named PHY sub-packages, +chan, and the stack layers.
case "$F" in
  *"+phy/+ts38"*|*"+phy/+chan/"*|*"/+mac/"*|*"/+rlc/"*|*"/+pdcp/"*|*"/+sdap/"*|*"/+pc5s/"*|*"/+cfg/"*)
    if printf '%s' "$C" | grep -Eq '\b(nr[A-Z][A-Za-z]*|lte[A-Z][A-Za-z]*|comm\.[A-Z]|dsp\.[A-Z])\('; then
      echo "Denied: toolbox call in a normative package. Wrap it in +phy/+lib/ and call the wrapper." >&2
      exit 2
    fi
    if printf '%s' "$C" | grep -Eq '(^|\n)[[:space:]]*(persistent|global)[[:space:]]'; then
      echo "Denied: hidden state in a normative package. State must live in an explicit serialisable object." >&2
      exit 2
    fi
    ;;
esac
exit 0
