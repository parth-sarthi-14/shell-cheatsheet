# ---------------------------------------------------------------------------
#  Custom command lookup functions
#  Documented for `cheatsheet` — see ~/.cheatsheet.sh
#
#  Any argument you leave out is printed as <----> so the command is still
#  copy-pasteable and the gap is obvious.
# ---------------------------------------------------------------------------

# @group access

# @desc  Print the jarvis command to grant a user server access to a strategy FAMILY
# @usage family-access <username>
family_access() {
  echo "jarvis strategy-family users add ${1:-<---->} parth.sarthi -t server"
}

# @desc  Print the jarvis command to grant a user server access to a single STRATEGY
# @usage strat-access <username>
strat_access() {
  echo "jarvis strategy users add ${1:-<---->} parth.sarthi -t server"
}

# @desc  Show your own jarvis user record and current permissions
# @usage my-access
my_access() {
  echo "jarvis user get parth.sarthi"
}

# @desc  Print the command to list the admin users on a strategy
# @usage strat-admins <strat-name>
strat_admins() {
  echo "jarvis strategy get ${1:-<---->} | jq '.config.users | with_entries(select(.value | index(\"admin\")))'"
}

# @desc  Print the command to show a strategy's login details
# @usage login_info <strat-login>
login_info() {
  echo "jarvis strategy get ${1:-<---->} | grep login"
}

# @group trading

# @desc  Print the command to fetch the traded universe for a strategy family
# @usage get-uni <strategy_family>
get_uni() {
  echo "trading_controller_cli custom connect-strategy --strategy_family ${1:-<---->} -c 'trading get universe' --skip_dry_run_check"
}

# @desc  Print the command to fetch the traded universe for a whole exchange
# @usage get-ex-uni <exchange>
get_ex_uni() {
  echo "trading_controller_cli custom connect-strategy --exchange ${1:-<---->} --command \"trading get universe\" --skip_dry_run_check"
}

# @desc  Print the command to query/apply a risk limit on a strategy family
# @usage rms <strategy_family> <risk_limit_args>
rms() {
  echo "trading_controller_cli custom connect-strategy --strategy_family ${1:-<---->} --command 'risk_limit ${2:-<---->}' --skip_dry_run_check"
}

# @desc  Print the dry-run command to read a strategy family's current state
# @usage strat-state <strategy_family>
strat_state() {
  echo "trading_controller_cli utils get-strat-state --strategy_family ${1:-<---->} --dry_run"
}

# @desc  Print the dry-run + live commands to set a family's trading mode
# @usage set_trading_mode <strategy_family> <mode>
set_trading_mode() {
  cat <<EOF
trading_controller_cli custom connect-strategy --strategy-family ${1:-<---->} -c 'trading set ${2:-<---->}' --skip_dry_run_check
EOF
}

# @desc  Print the command to create an overnight file for a strategy on a given date
# @usage create_on_file <strategy> <date>
create_on_file() {
  echo "jarvis strategy create-overnight ${1:-<---->} --date ${2:-<---->}"
}

# @desc  Print the command to fetch positions created by trading for a strategy on a date
# @usage get_strat_position <strat_name> <date>
get_strat_position() {
  echo "get_position_snappr -s ${1:-<---->} -d ${2:-<---->}"
}

# @desc  Print the command to start strategy orders for a family
# @usage strat_orders <family_name>
strat_orders() {
  echo "trading_controller_cli start strategy --strategy_family ${1:-<---->} --skip_dry_run_check"
}

# @group restarts

# @desc  Full safe restart runbook for a binary: check .err, bounce, verify recovery counts, start trade
# @usage bounce_binary <strat>
restart_binaries() {
  cat <<EOF
# 1. Verify no unexpected errors
cat $(date +%Y%m%d).err

# 1. Stop sending new strategy orders
trading_controller_cli stop strategy --strategy_family ${1:-<---->} --dry_run

# 2. Confirm no open orders
trading_controller_cli custom connect-strategy --strategy_family ${1:-<---->} -c "num_open_orders" --skip_dry_run_check

# 3. Restart binary
trading_controller_cli restart binaries ${1:-<---->} --dry_run
trading_controller_cli restart binaries ${1:-<---->}

# 4. Wait for Slack/OpsGenie confirmation in nexus high channel that binaries restarted, then re-verify .err

# 5. Check recovery counts — ALL must be zero
trading_controller_cli custom connect-strategy ${1:-<---->} -c "recovery_count_info" --skip_dry_run_check

# 6. Only if all counts are zero -> start trade
trading_controller_cli start trade --strat ${1:-<---->} --skip_dry_run_check

# 7. Start strategy orders
trading_controller_cli start strategy --strategy_family ${1:-<---->} --skip_dry_run_check
EOF
}

# @desc  Print dry-run + live commands to restart binaries for one strategy
# @usage bounce_strat <strat>
bounce_strat() {
  cat <<EOF
trading_controller_cli restart binaries --strat ${1:-<---->} --dry_run
trading_controller_cli restart binaries --strat ${1:-<---->}
EOF
}

# @desc  Print dry-run + live commands to restart binaries for a whole family
# @usage bounce_family <strategy_family>
bounce_family() {
  cat <<EOF
trading_controller_cli restart binaries --strategy-family ${1:-<---->} --dry_run
trading_controller_cli restart binaries --strategy-family ${1:-<---->}
EOF
}

# @group runbooks

# @desc  Triage protocol + commands for NoTrade / NoOrder alerts
# @usage No-order <strategy_family>
No_order() {
  local family="${1:-<---->}"
  cat << EOF
Initial protocol for NoTrade and NoOrder alerts.

1. Check recovery_count_info -> should be all 0
2. Check trading mode -> should be NORMAL
3. Check rms_hits -> If some rms is continuously being hit recently that needs to be flagged. Might not get alert for this since it might be in grepignore.
4. Monitor the following columns in portfolio.total for some iterations -> filled_qty (this will increase if any trade happens), n_requests_sent_post_bounce (this will increase if any order is sent from strategy). These get logged every 10 seconds, so if this does not change for 1-2 minutes then we can check the alphas. If this does change then the alert was a false positive and we might have to increase freq.
5. Alphas will be strategy specific so you will need to understand from strategy managers on what to check on alpha side.

Commands:

trading_controller_cli custom connect-strategy --strategy_family ${family} -c "recovery_count_info" --skip_dry_run_check

trading_controller_cli custom connect-strategy --strategy_family ${family} -c 'trading get universe' --skip_dry_run_check

cat *.portfolio.total | awk -F, '
NR==1 {
  for (i=1; i<=NF; i++) {
    if (\$i=="time") t=i
    if (\$i=="filled_qty") f=i
    if (\$i=="n_requests_sent_post_bounce") n=i
  }
}
{ print \$t","\$f","\$n }
' | vd -f csv
	
EOF
}

# @desc  Steps to inspect a crashed process core dump instead of blindly bouncing
# @usage segfault <pid_or_binary>
segfault() {
  cat <<EOF
# Don't bounce blindly
coredumpctl list          # list crashed processes
coredumpctl gdb ${1:-<---->}        # then at the (gdb) prompt:
bt                        # backtrace
EOF
}

# @desc  Print both argus liquidation-coverage checks (lenient and strict-zero)
# @usage liquidation_check
liquidation_check() {
  cat <<'EOF'
# blank = zero
python3 ~/argus-coverage/argus_coverage.py --liquidated
# blank ≠ zero
python3 ~/argus-coverage/argus_coverage.py --liquidated --strict-zero
EOF
}

# @desc  Runbook to back up, replace and sync a strategy's ON file to S3
# @usage add_on_file <strat-name> <File_name> <TIME>
add_on_file() {
  cat <<EOF
# 1. Check the existing ON file
jssh ${1:-<---->}
cd ${1:-<---->}/on
ls -1 | grep ${2:-<---->}.on.csv

# 2. Take a backup of the original file
cp -p ${2:-<---->}.on.csv ${2:-<---->}.on.$(date +%H%M).csv

# 3. Copy the modified on.csv into place as the dated file

# 4. Sync both files to S3 - dry run first
s3cmd put --dry-run ${2:-<---->}.on.csv s3://prodlogs-india/${1:-<---->}/on/
s3cmd put --dry-run ${2:-<---->}.on.${3:-<---->}.csv s3://prodlogs-india/${1:-<---->}/on/

# 5. If the dry run looks right, repeat both without --dry-run
s3cmd put ${2:-<---->}.on.csv s3://prodlogs-india/${1:-<---->}/on/
s3cmd put ${2:-<---->}.on.${3:-<---->}.csv s3://prodlogs-india/${1:-<---->}/on/
EOF
}

# @group logs

# @desc  Sum BSE+NSE margin factors between two timestamps, printing rows above 0.97
# @usage alfredM-margin <file_suffix> <start_time> <end_time>
alfredM_margin() {
  local filename="${1:-<---->}"
  local time1="${2:-<---->}"
  local time2="${3:-<---->}"
  cat << EOF
cat *.${filename} | awk -F',' '
\$1=="date" {
  for (i=1; i<=NF; i++) {
    if (\$i=="time") t_col=i
    if (\$i=="T_BSE_margin_factor") bse_col=i
    if (\$i=="T_NSE_margin_factor") nse_col=i
  }
  if (!header_printed) { print "time,sum"; header_printed=1 }
  next
}
{
  if (\$t_col >= "${time1}" && \$t_col <= "${time2}") {
    row_sum = \$bse_col + \$nse_col
    if (row_sum > 0.97) {
      print \$t_col "," row_sum
    }
  }
}'
EOF
}

# @desc  Open time/symbol/open-interest columns of a CSV in visidata
# @usage ind_max_perc_open_interest <file>
ind_max_perc_open_interest() {
  echo "cat ${1:-<---->} | awk -F, 'NR==1{for(i=1;i<=NF;i++) h[\$i]=i} {print \$h[\"time\"],\$h[\"symbol\"],\$h[\"oi\"]}' OFS=, | vd -f csv"
}

# --- make every function above print + copy to clipboard --------------------
type _clip_wrap_file >/dev/null 2>&1 && _clip_wrap_file ~/.trading-functions.sh
type _cs_md_autoupdate >/dev/null 2>&1 && _cs_md_autoupdate
