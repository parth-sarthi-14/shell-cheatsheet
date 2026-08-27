# ---------------------------------------------------------------------------
#  cheatsheet — a live, self-updating index of your shell functions & aliases
#
#  Install:   cp cheatsheet.sh ~/.cheatsheet.sh
#             echo 'source ~/.cheatsheet.sh' >> ~/.zshrc
#
#  Document a function by putting tag comments directly above it:
#
#      # @group trading
#      # @desc  Print the command to fetch a strategy family's universe
#      # @usage get-uni <strategy_family>
#      get-uni() { ... }
#
#  Nothing is cached or generated — the list is parsed from your rc files
#  every time you run it, so new functions appear the moment you save.
# ---------------------------------------------------------------------------

# Colon-separated list of files to scan. Override before sourcing if needed.
: ${CHEATSHEET_FILES:="$HOME/.zshrc:$HOME/.bashrc:$HOME/.bash_profile:$HOME/.aliases:$HOME/.functions:$HOME/.trading-functions.sh"}

_cs_files() {
  printf '%s\n' "$CHEATSHEET_FILES" | tr ':' '\n' | while IFS= read -r f; do
    [ -n "$f" ] && [ -r "$f" ] && printf '%s\n' "$f"
  done
}

_cs_scan() {
  _cs_files | while IFS= read -r f; do
    awk '
      function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
      function unquote(s) {
        s = trim(s)
        sub(/[ \t]*#.*$/, "", s)
        s = trim(s)
        if (s ~ /^".*"$/ || s ~ /^'"'"'.*'"'"'$/)
          s = substr(s, 2, length(s) - 2)
        return s
      }
      {
        s = $0
        top = ($0 !~ /^[ \t]/)      # real definitions live at column 0
        sub(/^[ \t]+/, "", s)

        # ---- tag comments -------------------------------------------------
        if (s ~ /^#[ \t]*@(desc|usage|group)/) {
          t = s; sub(/^#[ \t]*@/, "", t)
          tag = t; sub(/[ \t:].*$/, "", tag)
          val = t; sub(/^[A-Za-z]+[ \t:]*/, "", val); val = trim(val)
          if (tag == "desc")       desc  = val
          else if (tag == "usage") usage = val
          else if (tag == "group") group = val
          next
        }
        if (s ~ /^#/) next                       # plain comment: keep pending tags
        if (s == "")  { desc=""; usage=""; next }

        # ---- function definitions ------------------------------------------
        name = ""
        if (!top) { desc=""; usage=""; next }
        if (s ~ /^function[ \t]+[A-Za-z_][A-Za-z0-9_.:-]*/) {
          name = s; sub(/^function[ \t]+/, "", name); sub(/[ \t(].*$/, "", name)
        } else if (s ~ /^[A-Za-z_][A-Za-z0-9_.:-]*[ \t]*\(\)/) {
          name = s; sub(/[ \t(].*$/, "", name)
        }
        if (name != "") {
          # skip private helpers (_foo) so internals never clutter the list
          if (name !~ /^_/)
            print "fn\t" group "\t" name "\t" usage "\t" desc "\t" FILENAME
          desc=""; usage=""; next
        }

        # ---- aliases --------------------------------------------------------
        if (s ~ /^alias[ \t]+/) {
          a = s; sub(/^alias[ \t]+/, "", a)
          if (a ~ /^-/) sub(/^-[A-Za-z]+[ \t]+/, "", a)
          nm = a; sub(/=.*$/, "", nm)
          vl = a; sub(/^[^=]*=/, "", vl)
          print "al\t" group "\t" nm "\t" unquote(vl) "\t" desc "\t" FILENAME
          desc=""; usage=""; next
        }

        desc=""; usage=""
      }
    ' "$f"
  done
}

# @group meta
# @desc  Show this index of all your shell functions and aliases
# @usage cheatsheet [term] [-l|-s <name>|-t|-f|-h]
cheatsheet() {
  local filter="" mode="list" target="" verbose=0

  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help)              mode="help";    shift ;;
      -l|--long|-v|--verbose) verbose=1;      shift ;;
      -f|--files)             mode="files";   shift ;;
      -t|--todo)              mode="todo";    shift ;;
      -s|--show|show)         mode="show"; target="$2"; shift 2 ;;
      --)                     shift ;;
      *)                      filter="$1";    shift ;;
    esac
  done

  case "$mode" in
    help)
      cat <<'EOF'
cheatsheet — index of your shell functions and aliases

  cheatsheet                 list everything, grouped
  cheatsheet <term>          filter by name, group or description
  cheatsheet -l              also show usage lines and source file
  cheatsheet -s <name>       print the full definition of one function
  cheatsheet -t              list functions that still have no @desc
  cheatsheet -f              show which files are being scanned

Document a function with tag comments placed directly above it:

  # @group trading
  # @desc  What it does, in one line
  # @usage my-func <arg1> [arg2]
  my-func() { ... }

@group is sticky: it applies to everything below it until the next @group.
EOF
      return 0 ;;

    files)
      _cs_files
      return 0 ;;

    show)
      [ -z "$target" ] && { echo "cheatsheet: -s needs a function name" >&2; return 1; }
      if [ -n "$ZSH_VERSION" ]; then whence -f "$target"; else type "$target"; fi
      return $? ;;
  esac

  # colours (disabled when piping, or when NO_COLOR is set)
  local HDR="" NAME="" DIM="" RST=""
  if [ -t 1 ] && [ -z "$NO_COLOR" ]; then
    HDR=$'\033[1;38;5;39m'; NAME=$'\033[1;38;5;186m'
    DIM=$'\033[2;37m';      RST=$'\033[0m'
  fi

  _cs_scan | awk -F'\t' \
      -v flt="$filter" -v verbose="$verbose" -v todo="$([ "$mode" = todo ] && echo 1)" \
      -v HDR="$HDR" -v NAME="$NAME" -v DIM="$DIM" -v RST="$RST" '
    {
      if (todo == "1" && $5 != "") next
      if (flt != "") {
        hay = tolower($2 " " $3 " " $4 " " $5)
        if (index(hay, tolower(flt)) == 0) next
      }
      n++
      kind[n]=$1; grp[n]=($2=="" ? "ungrouped" : $2); nm[n]=$3
      us[n]=$4;   de[n]=$5;  fl[n]=$6
      if (length($3) > w) w = length($3)
      if (!(grp[n] in seen)) { seen[grp[n]] = 1; order[++ng] = grp[n] }
    }
    END {
      if (n == 0) { print "  nothing found"; exit }
      fmt = "  " NAME "%-" w "s" RST "  %s\n"
      pad = sprintf("%-" w "s", "")
      for (g = 1; g <= ng; g++) {
        printf "\n%s%s%s\n", HDR, toupper(order[g]), RST
        for (i = 1; i <= n; i++) {
          if (grp[i] != order[g]) continue
          d = de[i]
          if (d == "") d = DIM "(undocumented)" RST
          if (kind[i] == "al") d = d "  " DIM "→ " us[i] RST
          printf fmt, nm[i], d
          if (verbose && kind[i] == "fn") {
            if (us[i] != "") printf "  %s  %s%s%s\n", pad, DIM, us[i], RST
            printf "  %s  %s%s%s\n", pad, DIM, fl[i], RST
          }
        }
      }
      printf "\n"
    }
  '
}

# tab-completion for `cheatsheet -s <name>`
if [ -n "$ZSH_VERSION" ]; then
  eval '_cheatsheet_complete() { reply=( ${(f)"$(_cs_scan | cut -f3)"} ) }
        compctl -K _cheatsheet_complete cheatsheet'
elif [ -n "$BASH_VERSION" ]; then
  _cheatsheet_complete() {
    COMPREPLY=( $(compgen -W "$(_cs_scan | cut -f3 | tr '\n' ' ')" -- "${COMP_WORDS[COMP_CWORD]}") )
  }
  complete -F _cheatsheet_complete cheatsheet
fi

# --- clipboard: print output and copy it ------------------------------------
_clip_emit() {
  local out
  out="$(cat)"
  printf '%s\n' "$out"
  if [ -t 1 ] && command -v pbcopy >/dev/null 2>&1; then
    printf '%s' "$out" | pbcopy
    printf '\033[2m(copied to clipboard)\033[0m\n' >&2
  fi
}

_clip_wrap_file() {
  local file="$1" f
  [ -r "$file" ] || return 0
  for f in $(awk '/^[A-Za-z][A-Za-z0-9_.:-]*[ \t]*\(\)/ {sub(/[ \t(].*$/,""); print}' "$file"); do
    (( ${+functions[$f]} )) || continue
    case "${functions[$f]}" in *_clip_emit*) continue ;; esac
    functions -c "$f" "_orig_$f"
    eval "${f}() { _orig_${f} \"\$@\" | _clip_emit }"
  done
}


# --- markdown export --------------------------------------------------------
: ${CHEATSHEET_MD:="$HOME/trading-cheatsheet.md"}
: ${CHEATSHEET_MD_SKIP:="cheatsheet cheatsheet-md"}

# @group meta
# @desc  Regenerate the markdown cheatsheet from your shell config
# @usage cheatsheet-md [output_file]
cheatsheet-md() {
  local out="${1:-$CHEATSHEET_MD}"
  local tmp="${out}.tmp.$$"

  # Subshell: the frozen `date` below dies with it, keeping output reproducible
  # so the markdown only changes when a command actually changes.
  (
    date() { printf '<DATE>'; }

    printf '# Command Cheatsheet\n\n'
    printf 'Generated from `cheatsheet.sh` and `trading-functions.sh` — do not edit by hand.\n'
    printf 'Edit the source files, then run `cheatsheet-md` (or open a new shell).\n\n'

    _cs_scan | awk -F'\t' '
      { g = ($2 == "" ? "ungrouped" : $2)
        if (!(g in seen)) { seen[g] = 1; order[++n] = g } }
      END { print "## Contents"; print ""
            for (i = 1; i <= n; i++) printf "- [%s](#%s)\n", order[i], order[i] }
    '

    local prev="" kind grp name usage desc file body
    _cs_scan | awk -F'\t' -v OFS='\t' '
      { for (i = 1; i <= NF; i++) if ($i == "") $i = "-"; print }
    ' | while IFS=$'\t' read -r kind grp name usage desc file; do
      [ "$grp" = "-" ] && grp="ungrouped"
      [ "$usage" = "-" ] && usage=""
      [ "$desc" = "-" ] && desc=""

      if [ "$grp" != "$prev" ]; then
        printf '\n## %s\n' "$grp"
        prev="$grp"
      fi

      printf '\n### `%s`\n\n' "$name"
      [ -n "$desc" ] && printf '%s\n\n' "$desc"

      if [ "$kind" = "al" ]; then
        printf '```sh\nalias %s=%s\n```\n' "$name" "$usage"
        continue
      fi

      [ -n "$usage" ] && printf '**Usage:** `%s`\n\n' "$usage"

      case " $CHEATSHEET_MD_SKIP " in
        *" $name "*) continue ;;
      esac

      body="$( "$name" 2>/dev/null )"
      [ -n "$body" ] && printf '```sh\n%s\n```\n' "$body"
    done

    printf '\n'
  ) > "$tmp" && mv "$tmp" "$out"

  [ -t 1 ] && printf 'wrote %s\n' "$out"
  return 0
}

_cs_md_autoupdate() {
  local md="$CHEATSHEET_MD" f stale=0
  [ -f "$md" ] || stale=1
  for f in $(_cs_files); do
    [ "$f" -nt "$md" ] && stale=1
  done
  [ "$stale" = "1" ] && cheatsheet-md >/dev/null 2>&1
  return 0
}
