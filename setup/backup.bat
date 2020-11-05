cd C:\Users\mittaaja\Desktop\hobocopy
hobocopy /full /recursive "C:\Users\mittaaja\Desktop\nais-5-7\nais-5-7-config-20181229\nais-5-7-data" "C:\Users\mittaaja\Desktop\nais-5-7-data-snapshot"
cd C:\"Program Files (x86)"\WinSCP
winscp.com /command ^ "open jfj" ^ "cd /data" ^ "lcd C:\Users\mittaaja\Desktop\nais-5-7-data-snapshot" ^ "put * ./" ^ "exit"