# Command Cheatsheet

Generated from `cheatsheet.sh` and `trading-functions.sh` — do not edit by hand.
Edit the source files, then run `cheatsheet-md` (or open a new shell).

## Contents

- [access](#access)
- [trading](#trading)
- [restarts](#restarts)
- [runbooks](#runbooks)
- [logs](#logs)

## access

### `family_access`

Print the jarvis command to grant a user server access to a strategy FAMILY

**Usage:** `family-access <username>`

```sh
jarvis strategy-family users add <----> parth.sarthi -t server
```

### `strat_access`

Print the jarvis command to grant a user server access to a single STRATEGY

**Usage:** `strat-access <username>`

```sh
jarvis strategy users add <----> parth.sarthi -t server
```

### `my_access`

Show your own jarvis user record and current permissions

**Usage:** `my-access`

```sh
jarvis user get parth.sarthi
```

### `strat_admins`

Print the command to list the admin users on a strategy

**Usage:** `strat-admins <strat-name>`

```sh
jarvis strategy get <----> | jq '.config.users | with_entries(select(.value | index("admin")))'
```

### `login_info`

Print the command to show a strategy's login details

**Usage:** `login_info <strat-login>`

```sh
jarvis strategy get <----> | grep login
```

## trading

### `get_uni`

Print the command to fetch the traded universe for a strategy family

**Usage:** `get-uni <strategy_family>`

```sh
trading_controller_cli custom connect-strategy --strategy_family <----> -c 'trading get universe' --skip_dry_run_check
```

### `get_ex_uni`

Print the command to fetch the traded universe for a whole exchange

**Usage:** `get-ex-uni <exchange>`

```sh
trading_controller_cli custom connect-strategy --exchange <----> --command "trading get universe" --skip_dry_run_check
```

### `rms`

Print the command to query/apply a risk limit on a strategy family

**Usage:** `rms <strategy_family> <risk_limit_args>`

```sh
trading_controller_cli custom connect-strategy --strategy_family <----> --command 'risk_limit <---->' --skip_dry_run_check
```

### `strat_state`

Print the dry-run command to read a strategy family's current state

**Usage:** `strat-state <strategy_family>`

```sh
trading_controller_cli utils get-strat-state --strategy_family <----> --dry_run
```

### `set_trading_mode`

Print the dry-run + live commands to set a family's trading mode

**Usage:** `set_trading_mode <strategy_family> <mode>`

```sh
trading_controller_cli custom connect-strategy --strategy-family <----> -c 'trading set <---->' --skip_dry_run_check
```

### `create_on_file`

Print the command to create an overnight file for a strategy on a given date

**Usage:** `create_on_file <strategy> <date>`

```sh
jarvis strategy create-overnight <----> --date <---->
```

### `get_strat_position`

Print the command to fetch positions created by trading for a strategy on a date

**Usage:** `get_strat_position <strat_name> <date>`

```sh
get_position_snappr -s <----> -d <---->
```

### `strat_orders`

Print the command to start strategy orders for a family

**Usage:** `strat_orders <family_name>`

```sh
trading_controller_cli start strategy --strategy_family <----> --skip_dry_run_check
```

### `recovery_count`

Print the command to check recovery counts for a strategy family

**Usage:** `recovery_count <family-name>`

```sh
trading_controller_cli custom connect-strategy --strategy_family <----> -c "recovery_count_info" --skip_dry_run_check
```

### `exchange_strats`

List the strategies running on an exchange, space-separated on one line

**Usage:** `exchange_strats <nsecm|nsefo|bsefo|bsecm>`

```sh
usage: exchange_strats <nsecm|nsefo|bsefo|bsecm>
```

## restarts

### `restart_binaries`

Full safe restart runbook for a binary: check .err, bounce, verify recovery counts, start trade

**Usage:** `bounce_binary <strat>`

```sh
# 1. Verify no unexpected errors
cat <DATE>.err

# 1. Stop sending new strategy orders
trading_controller_cli stop strategy --strategy_family <----> --dry_run

# 2. Confirm no open orders
trading_controller_cli custom connect-strategy --strategy_family <----> -c "num_open_orders" --skip_dry_run_check

# 3. Restart binary
trading_controller_cli restart binaries <----> --dry_run
trading_controller_cli restart binaries <---->

# 4. Wait for Slack/OpsGenie confirmation in nexus high channel that binaries restarted, then re-verify .err

# 5. Check recovery counts — ALL must be zero
trading_controller_cli custom connect-strategy <----> -c "recovery_count_info" --skip_dry_run_check

# 6. Only if all counts are zero -> start trade
trading_controller_cli start trade --strat <----> --skip_dry_run_check

# 7. Start strategy orders
trading_controller_cli start strategy --strategy_family <----> --skip_dry_run_check
```

### `bounce_strat`

Print dry-run + live commands to restart binaries for one strategy

**Usage:** `bounce_strat <strat>`

```sh
trading_controller_cli restart binaries --strat <----> --dry_run
trading_controller_cli restart binaries --strat <---->
```

### `bounce_family`

Print dry-run + live commands to restart binaries for a whole family

**Usage:** `bounce_family <strategy_family>`

```sh
trading_controller_cli restart binaries --strategy-family <----> --dry_run
trading_controller_cli restart binaries --strategy-family <---->
```

## runbooks

### `No_order`

Triage protocol + commands for NoTrade / NoOrder alerts

**Usage:** `No_order <strategy_family>`

```sh
Initial protocol for NoTrade and NoOrder alerts.

1. Check recovery_count_info -> should be all 0
2. Check trading mode -> should be NORMAL
3. Check rms_hits -> If some rms is continuously being hit recently that needs to be flagged. Might not get alert for this since it might be in grepignore.
4. Monitor the following columns in portfolio.total for some iterations -> filled_qty (this will increase if any trade happens), n_requests_sent_post_bounce (this will increase if any order is sent from strategy). These get logged every 10 seconds, so if this does not change for 1-2 minutes then we can check the alphas. If this does change then the alert was a false positive and we might have to increase freq.
5. Alphas will be strategy specific so you will need to understand from strategy managers on what to check on alpha side.

Commands:

trading_controller_cli custom connect-strategy --strategy_family <----> -c "recovery_count_info" --skip_dry_run_check

trading_controller_cli custom connect-strategy --strategy_family <----> -c 'trading get universe' --skip_dry_run_check

cat *.portfolio.total | awk -F, '
NR==1 {
 for (i=1; i<=NF; i++) {
  if ($i=="time") t=i
  if ($i=="filled_qty") f=i
  if ($i=="n_requests_sent_post_bounce") n=i
  if ($i=="open_buy_qty") ob=i
  if ($i=="open_long_sell_qty") ols=i
  if ($i=="open_short_sell_qty") oss=i
 }
 print $t","$f","$n",open_total_qty"
 next
}
{ print $t","$f","$n","($ob+$ols+$oss) }
' | vd -f csv


5b. Detect stalled rows (repeated time / filled_qty / n_requests values):

awk -F, '
function clean(s) { gsub(/^[ \t\r"]+|[ \t\r"]+$/, "", s); return s }
FNR==1 {
  t=0; f=0; n=0; have=0; shown=0
  for (i=1; i<=NF; i++) {
    h = clean($i)
    if (h=="time") t=i
    if (h=="filled_qty") f=i
    if (h=="n_requests_sent_post_bounce") n=i
  }
  if (!t || !f || !n) { print "header not matched in " FILENAME > "/dev/stderr"; exit 1 }
  if (!hdr++) print "time,filled_qty,n_requests_sent_post_bounce,match"
  next
}
{
  T = clean($t); F = clean($f)+0; N = clean($n)+0
  cur = T","F","N
  m = ""
  if (have) {
    if (T==pT) m = m "T"
    if (F==pF) m = m "F"
    if (N==pN) m = m "N"
  }
  if (m != "") {
    if (!shown) print prev","m
    print cur","m
    shown = 1
  } else shown = 0
  prev=cur; pT=T; pF=F; pN=N; have=1
}
' *.portfolio.total | vd -f csv
```

### `clean`


### `segfault`

Steps to inspect a crashed process core dump instead of blindly bouncing

**Usage:** `segfault <pid_or_binary>`

```sh
# Don't bounce blindly
coredumpctl list          # list crashed processes
coredumpctl gdb <---->        # then at the (gdb) prompt:
bt                        # backtrace
```

### `liquidation_check`

Print both argus liquidation-coverage checks (lenient and strict-zero)

**Usage:** `liquidation_check`

```sh
# blank = zero
python3 ~/argus-coverage/argus_coverage.py --liquidated
# blank ≠ zero
python3 ~/argus-coverage/argus_coverage.py --liquidated --strict-zero
```

### `add_on_file`

Runbook to back up, replace and sync a strategy's ON file to S3

**Usage:** `add_on_file <strat-name> <File_name> <TIME>`

```sh
# 1. Check the existing ON file
jssh <---->
cd <---->/on
ls -1 | grep <---->.on.csv

# 2. Take a backup of the original file
cp -p <---->.on.csv <---->.on.<DATE>.csv

# 3. Copy the modified on.csv into place as the dated file

# 4. Sync both files to S3 - dry run first
s3cmd put --dry-run <---->.on.csv s3://prodlogs-india/<---->/on/
s3cmd put --dry-run <---->.on.<---->.csv s3://prodlogs-india/<---->/on/

# 5. If the dry run looks right, repeat both without --dry-run
s3cmd put <---->.on.csv s3://prodlogs-india/<---->/on/
s3cmd put <---->.on.<---->.csv s3://prodlogs-india/<---->/on/
```

## logs

### `alfredM_margin`

Sum BSE+NSE margin factors between two timestamps, printing rows above 0.97

**Usage:** `alfredM-margin <file_suffix> <start_time> <end_time>`

```sh
cat *.<----> | awk -F',' '
$1=="date" {
  for (i=1; i<=NF; i++) {
    if ($i=="time") t_col=i
    if ($i=="T_BSE_margin_factor") bse_col=i
    if ($i=="T_NSE_margin_factor") nse_col=i
  }
  if (!header_printed) { print "time,sum"; header_printed=1 }
  next
}
{
  if ($t_col >= "<---->" && $t_col <= "<---->") {
    row_sum = $bse_col + $nse_col
    if (row_sum > 0.97) {
      print $t_col "," row_sum
    }
  }
}'
```

### `ind_max_perc_open_interest`

Open time/symbol/open-interest columns of a CSV in visidata

**Usage:** `ind_max_perc_open_interest <file>`

```sh
cat <----> | awk -F, 'NR==1{for(i=1;i<=NF;i++) h[$i]=i} {print $h["time"],$h["symbol"],$h["oi"]}' OFS=, | vd -f csv
```

