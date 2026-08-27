# shell-cheatsheet

Shell functions that print (and copy to clipboard) the commands I use most,
plus a `cheatsheet` command that indexes them and a markdown export that
regenerates itself.

## Install

    git clone <this-repo> ~/shell-cheatsheet
    ln -s ~/shell-cheatsheet/cheatsheet.sh        ~/.cheatsheet.sh
    ln -s ~/shell-cheatsheet/trading-functions.sh ~/.trading-functions.sh

Then add to `~/.zshrc`:

    CHEATSHEET_MD="$HOME/shell-cheatsheet/trading-cheatsheet.md"
    source ~/.cheatsheet.sh
    source ~/.trading-functions.sh

## Usage

    cheatsheet              list everything, grouped
    cheatsheet <term>       filter
    cheatsheet -s <name>    show a function's definition
    cheatsheet -t           list undocumented functions
    cheatsheet-md           regenerate trading-cheatsheet.md

Adding a function: edit `trading-functions.sh`, put `# @desc` and `# @usage`
comments above it, then `source ~/.zshrc`.
