#!/bin/sh

#WIFI_NAME_HERE in deploy.sh needs to be replaced with the WIFI name of the guest network.
#Assumption is that you only have 3 or less network interfaces. While loop in rotate_guest_wifi_password needs to be increased otherwise


WIFI_NAME="" #REPLACE THIS WITH YOUR WIFI_NAME

if [ -z "$WIFI_NAME" ]; then
    echo "Please set the WIFI_NAME variable in the script"
    exit 1
fi
rotate_script=$(mktemp)
guest_script=$(mktemp)


cat <<EOF > "$rotate_script"
#!/bin/sh

password=\$(cat /dev/urandom | env LC_CTYPE=C tr -dc A-HJ-NP-Za-kmnp-z2-9 | head -c 8; echo;)

echo \$password > /root/.guest_password.txt

ssid=$WIFI_NAME
security=WPA
i=0
while [ \$i -le 2 ]; do
    if [ "\$(uci get wireless.@wifi-iface[\$i].network)" = 'guest' ]; then
        uci set wireless.@wifi-iface[\$i].key=\$password
        uci commit wireless
        wifi
    fi
    i=\$((i+1))
done

qrencode --type=SVG -o /www/images/wifi.svg "WIFI:S:\$ssid;T:\$security;P:\$password;;" 

EOF

chmod +x "$rotate_script"
mv "$rotate_script" /sbin/rotate_guest_wifi_password.sh

cat <<EOF > "$guest_script"
#!/bin/sh

password=\$(cat /root/.guest_password.txt)

echo "Content-Type: text/html"
echo ""
echo "<!DOCTYPE html>"
echo '<html lang="en-US">'
echo "<head>"
echo "<title>Guest WIFI Password</title>"
echo '<meta name="viewport" content="width=device-width, height=device-height, initial-scale=1.0, minimum-scale=1.0">'
echo '<meta http-equiv="refresh" content="360" />'
echo "</head>"
echo '<body bgcolor=\"#000\">'
echo "<div style='text-align:center;color:#fff;font-family:UnitRoundedOT,Helvetica Neue,Helvetica,Arial,sans-serif;font-size:28px;font-weight:500;'>"
echo "<h1>Guest WIFI Password</h1>"
echo "<p>SSID: <b>$WIFI_NAME</b></p>"
echo "<p>PASSWORD: <b>\$password</b></p>"
echo '<img src=../images/wifi.svg style="width:100%;max-width:600px;"></img><br>'
echo "</div>"
echo "</body>"
echo "</html>"
EOF

chmod +x "$guest_script"
mv "$guest_script" /www/cgi-bin/guest

if ! grep -q "rotate_guest_wifi_password.sh" /etc/crontabs/root; then
    echo "0 1 * * * /sbin/rotate_guest_wifi_password.sh" >> /etc/crontabs/root
else
    echo "Item already in Crontab"
fi
