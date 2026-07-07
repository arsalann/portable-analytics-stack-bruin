Output demos/portable-analytics-stack.gif

Require bruin
Require find
Require make
Require sed

Set Shell "zsh"
Set FontSize 24
Set Width 1500
Set Height 900
Set Padding 24
Set Framerate 24
Set PlaybackSpeed 1.1
Set TypingSpeed 18ms
Set Theme "Catppuccin Mocha"

Hide
Type "cd /Users/bear/conductor/workspaces/portable-analytics-stack-bruin/casablanca && clear"
Enter
Show

Type "printf 'Portable Analytics Stack\\nBruin + DuckLake + Cloudflare R2 + Neon\\n\\n'"
Enter
Sleep 1s

Type "find pipeline -maxdepth 3 -type f | sort"
Enter
Sleep 2s

Type "sed -n '1,24p' pipeline/pipeline.yml"
Enter
Sleep 2s

Type "make bruin-validate"
Enter
Sleep 4s

Type "make bruin-query QUERY='select crash_date, zip_code, collision_count from lakehouse.full_model order by crash_date desc, collision_count desc limit 5'"
Enter
Sleep 5s
