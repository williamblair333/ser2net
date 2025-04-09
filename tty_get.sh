tty_entry=$(find /sys/ -name $1 -type d 2>/dev/null | awk 'NR==1{print $1; exit}' )
echo $tty_entry
