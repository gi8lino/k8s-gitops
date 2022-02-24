# kube-prometheus-stack

## slack notification

### slack app

[create a slack app](https://api.slack.com/apps/)  
in Slack, `right click` on channel to post from Alertmanager  
click on `details`  
click on `integration`  
click on `Add app`  
add your `slack app`  
goto https://api.slack.com/apps  
click on your `App`  
Under `Features` click on `Incoming Webhooks`  
Click on `Add New Webhook to Workspace` and select desired `channel`  
Copy your `Webhook URL`
test alert:

```bash
kubectl exec -ti -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0 -- \
wget --post-data='[{"labels":{"alertname":"TestAlert1"}}]' localhost:9093/api/v1/alerts
```


## node exporter textfile collector scripts

### apt packages

add a cronjob on the host which execute the following script:

```bash
#!/bin/bash
#
# Description: Expose metrics from apt updates.
#
# Author: Ben Kochie <superq@gmail.com>

upgrades="$(/usr/bin/apt-get --just-print dist-upgrade \
  | /usr/bin/awk -F'[()]' \
      '/^Inst/ { sub("^[^ ]+ ", "", $2); gsub(" ","",$2);
                sub("\\[", " ", $2); sub("\\]", "", $2); print $2 }' \
  | /usr/bin/sort \
  | /usr/bin/uniq -c \
  | awk '{ gsub(/\\\\/, "\\\\", $2); gsub(/"/, "\\\"", $2);
          gsub(/\[/, "", $3); gsub(/\]/, "", $3);
          print "apt_upgrades_pending{origin=\"" $2 "\",arch=\"" $NF "\"} " $1}'
)"
autoremove="$(/usr/bin/apt-get --just-print autoremove \
  | /usr/bin/awk '/^Remv/{a++}END{printf "apt_autoremove_pending %d", a}'
)"
echo '# HELP apt_upgrades_pending Apt package pending updates by origin.'
echo '# TYPE apt_upgrades_pending gauge'
if [[ -n "${upgrades}" ]] ; then
  echo "${upgrades}"
else
  echo 'apt_upgrades_pending{origin="",arch=""} 0'
fi
echo '# HELP apt_autoremove_pending Apt package pending autoremove.'
echo '# TYPE apt_autoremove_pending gauge'
echo "${autoremove}"
echo '# HELP node_reboot_required Node reboot is required for software updates.'
echo '# TYPE node_reboot_required gauge'
if [[ -f '/var/run/reboot-required' ]] ; then
  echo 'node_reboot_required 1'
else
  echo 'node_reboot_required 0'
fi
```

## :hugs:&nbsp; Thanks

link to original dashboard:

- [node-exporter-full](https://grafana.com/grafana/dashboards/10242)
