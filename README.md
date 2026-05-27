# de_GWD (ARM-only)

基于 [jacyl4/de_GWD](https://github.com/jacyl4/de_GWD) (v1.26.5)，**仅 ARM64 适配分支**，不做功能修改。

* 具备流量整形加速的旁路网关
* 仅供学习与研究
* 内核仅支持 Zabbly (ARM 兼容)
* 在 ARM 平台自动跳过 IFB CAKE ingress（避免弱 CPU 过载）


[![Telegram](https://cdn.jsdelivr.net/gh/Patrolavia/telegram-badge@8fe3382b3fd3a1c533ba270e608035a27e430c2e/chat.svg)](https://t.me/de_GWD_DQ)  


## Server (arm64) support kvm xen openvz lxc and so on:
```
apt install -y wget
bash <(wget --no-check-certificate -qO- https://raw.githubusercontent.com/jacyl4/de_GWD/main/server)
```

![de_GWD 0](https://raw.githubusercontent.com/jacyl4/de_GWD/main/resource/screenshot/0.png)

## Client (arm64):
```
apt install -y wget
bash <(wget --no-check-certificate -qO- https://ghproxy.net/https://raw.githubusercontent.com/jacyl4/de_GWD/main/client)
```
或

手动上传client文件与de_GWD压缩包后
```
chmod +x client
./client
```

![de_GWD 1](https://raw.githubusercontent.com/jacyl4/de_GWD/main/resource/screenshot/1.png)
![de_GWD 2](https://raw.githubusercontent.com/jacyl4/de_GWD/main/resource/screenshot/2.png)
![de_GWD 3](https://raw.githubusercontent.com/jacyl4/de_GWD/main/resource/screenshot/3.png)
![de_GWD 4](https://raw.githubusercontent.com/jacyl4/de_GWD/main/resource/screenshot/4.png)
![de_GWD 5](https://raw.githubusercontent.com/jacyl4/de_GWD/main/resource/screenshot/5.png)

## 原始项目
* [jacyl4/de_GWD](https://github.com/jacyl4/de_GWD) — 原版（已归档，2025年10月）

## Thanks to
* [ XTLS/Xray-core ](https://github.com/XTLS/Xray-core)
* [ coredns/coredns ](https://github.com/coredns/coredns)
* [ pymumu/smartdns ](https://github.com/pymumu/smartdns)
* [ IrineSistiana/mosdns ](https://github.com/IrineSistiana/mosdns)
* [ m13253/dns-over-https ](https://github.com/m13253/dns-over-https)
* [ pi-hole/docker-pi-hole ](https://github.com/pi-hole/docker-pi-hole)
* [ mmotti/pihole-regex ](https://github.com/mmotti/pihole-regex)
* [ Loyalsoldier/v2ray-rules-dat ](https://github.com/Loyalsoldier/v2ray-rules-dat)
* [ makotom/cfspeed ](https://github.com/makotom/cfspeed)
* [ mzz2017/lkl-haproxy ](https://github.com/mzz2017/lkl-haproxy)
* [ zabbly/linux ](https://github.com/zabbly/linux)
* [ tsl0922/ttyd ](https://github.com/tsl0922/ttyd)
* [ mikefarah/yq ](https://github.com/mikefarah/yq)
* [ nyanmisaka/jellyfin ](https://hub.docker.com/r/nyanmisaka/jellyfin)
* [ dani-garcia/vaultwarden ](https://github.com/dani-garcia/vaultwarden)

## Stargazers over time
[![Stargazers over time](https://starchart.cc/jacyl4/de_GWD.svg)](https://starchart.cc/jacyl4/de_GWD)

[![Powered by DartNode](https://dartnode.com/branding/DN-Open-Source-sm.png)](https://dartnode.com "Powered by DartNode - Free VPS for Open Source")
