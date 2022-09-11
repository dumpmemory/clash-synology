# 群晖NAS部署clash透明代理
* 本教程采用Tun模式，基于闭源版本的clash premium，如需开源版本clash的配置方法，请前往[clash-synology-iptables](https://github.com/412999826/clash-synology/tree/iptables-mode)
* 可安装于ARM架构的群晖，无需Docker或虚拟机
* 可以由群晖开启DHCP服务器，并将网关和DNS指向群晖，即可实现局域网设备的自动全局代理
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
wget -qO- https://github.com/412999826/clash-synology/raw/tun-mode/install.sh| bash
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

2. 立即运行并设置系统启动时运行
```bash
systemctl start clash
systemctl enable clash
```

## 配置防火墙转发规则(iptables)
1. 如果需要代理udp流量,请取消脚本中`配置udp透明代理`部分内容的注释，请前往[syno-iptables](https://github.com/sjtuross/syno-iptables)下载/自行编译群晖缺失的iptables组件，并按上述仓库教程进行安装(无需运行加载命令，加载命令已经包含在脚本中)
2. 创建计划任务：启动时自动配置防火墙
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

# 启用TUN
mkdir -p /dev/net
mknod /dev/net/tun c 10 200
chmod 600 /dev/net/tun

# 启用CLASH
systemctl start clash

# DNS 相关配置
iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-port 1053
```

## 一键更新clash脚本（测试）
仅在DS118/DS218机型（armv8架构）测试通过，
```bash
wget -qO- https://github.com/412999826/clash-synology/raw/tun-mode/autoupdate.sh| bash
```
