# 群晖NAS部署clash透明代理(tun mode)
* 本教程基于闭源的clash premium，如需开源clash的配置方法，请前往[clash-redir-tproxy-mode](https://github.com/412999826/clash-synology/tree/iptables-mode)
* 本教程采用tun混合模式，即tcp-redir，udp-tun
* tun模式可以代理udp流量，且无需编译群晖缺失的组件
* 可安装于arm架构的群晖，无需docker或虚拟机
* 可以由群晖开启dhcp服务器，并将网关和dns指向群晖，即可实现局域网设备的自动全局代理
* 因为后续clash配置文件可能经常需要修改，建议将配置文件目录定义在`共享文件夹`目录下

安装过程需开启群晖的SSH功能，并通过`sudo -i`切换到root用户

请将群晖设置为静态IP

本文以armv8（aarch64）架构为例，且clash的配置目录为`/volume1/homes/clash`

## 安装clash

1. 下载最新版本，地址请前往[Dreamacro/clash premium](https://github.com/Dreamacro/clash/releases/tag/premium)，根据架构替换最新版本下载地址（以下以armv8架构为例）
```bash
wget -q https://github.com/Dreamacro/clash/releases/download/premium/clash-linux-armv8-2022.08.26.gz
```

2. 解压（请根据下载的文件名进行替换）
```bash
gzip -d clash-linux-armv8-2022.08.26.gz
```

3. 安装到系统 PATH（请根据下载的文件名进行替换）
```bash
chmod +x clash-linux-armv8-2022.08.26
mv clash-linux-armv8-2022.08.26 /usr/bin/clash
```

## 通过脚本安装clash（测试）
仅在DS118/DS218机型（armv8架构）测试通过，
```bash
wget -qO- https://github.com/412999826/clash-synology/raw/tun-mixed-mode/install.sh| bash
```

## 创建配置文件及安装控制面板

1. 创建配置文件目录(如果上文配置目录的路径为`共享文件夹`目录，也可右键新建文件夹)
```bash
mkdir -p /volume1/homes/clash
```

2. 下载clash控制面板，提供2个版本

* [Dreamacro/clash-dashboard](https://github.com/Dreamacro/clash-dashboard/archive/refs/heads/gh-pages.zip)

* [haishanh/yacd](https://github.com/haishanh/yacd/archive/refs/heads/gh-pages.zip)

4. 解压，并将控制面板目录重命名为clash-ui，上传至clash配置目录下

5. 创建yaml配置文件并存放到clash配置目录

    以下放出针对本次透明代理的重点内容，完整配置请前往[Dreamacro/clash Wiki](https://github.com/Dreamacro/clash/wiki/configuration#all-configuration-options)获取。

```bash
# HTTP端口
port: 7890
# SOCKS5端口
socks-port: 7891
# 透明代理端口
redir-port: 7892
#允许来自局域网的连接
allow-lan: true
日志级别
log-level: info
# 控制面板端口
external-controller: 0.0.0.0:9090
# 控制面板路径
external-ui: clash-ui
# 控制面板密码
secret: "123456"
# dns设置
dns:
  enable: true
  ipv6: false
  listen: 0.0.0.0:1053
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  nameserver:
    - 114.114.114.114
    - https://dns.alidns.com/dns-query
  fallback:
    - tls://8.8.4.4:853
    - https://dns.pub/dns-query
# tun模式设置
tun:
  enable: true
  stack: system # or gvisor
  dns-hijack:
    - any:53
    - tcp://any:53
  auto-route: true
  auto-detect-interface: true
# 域名劫持设置
hosts:
  #clash.dev: 192.168.1.1
  #'.dev': 127.0.0.1
    
```

## 设置clash自启动服务

1. Systemd 配置文件
* 启动vi编辑器
```bash
vi /etc/systemd/system/clash.service
```

* 按`I`进入编辑模式，键入以下内容（`-d` 后面键入clash配置文件目录）
```bash
[Unit]
Description=Clash daemon, A rule-based proxy in Go.
After=network.target

[Service]
Type=simple
Restart=always
ExecStart=/usr/bin/clash -d /volume1/homes/clash

[Install]
WantedBy=multi-user.target
```

* 按`ESC`，键入`:wq`退出

2. 运行clash
```bash
systemctl start clash
```

## 创建计划任务

* 转到：DSM>控制面板>计划任务
* 新增>触发的任务>用户定义的脚本
  * 常规
    * 任务：活动软件
    * 用户：root
    * 事件：启动
    * 任务前：无
  * 任务设置
    * 运行命令：（请参阅下面的命令）

```bash
#!/bin/bash

# 启用ipv4 forward
sysctl -w net.ipv4.ip_forward=1

# 定义环境变量
proxy_port=7892                  #clash 代理端口
dns_port=1053                    #clash dns监听端口

# 启用tun
mkdir -p /dev/net
mknod /dev/net/tun c 10 200
chmod 600 /dev/net/tun

# 启用clash
systemctl start clash

# 配置tcp透明代理
## 在nat表中新建clash规则链
iptables -t nat -N clash
## 排除环形地址与保留地址
iptables -t nat -A clash -d 0.0.0.0/8 -j RETURN
iptables -t nat -A clash -d 10.0.0.0/8 -j RETURN
iptables -t nat -A clash -d 127.0.0.0/8 -j RETURN
iptables -t nat -A clash -d 169.254.0.0/16 -j RETURN
iptables -t nat -A clash -d 172.16.0.0/12 -j RETURN
iptables -t nat -A clash -d 192.168.0.0/16 -j RETURN
iptables -t nat -A clash -d 224.0.0.0/4 -j RETURN
iptables -t nat -A clash -d 240.0.0.0/4 -j RETURN
## 重定向tcp流量到clash 代理端口
iptables -t nat -A clash -p tcp -j REDIRECT --to-port "$proxy_port"
## 拦截外部tcp数据并交给clash规则链处理
iptables -t nat -A PREROUTING -p tcp -j clash

# dns 相关配置
iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-port 1053
```

## 一键更新clash脚本（测试）
仅在DS118/DS218机型（armv8架构）测试通过，
```bash
wget -qO- https://github.com/412999826/clash-synology/raw/tun-mixed-mode/autoupdate.sh| bash
```
