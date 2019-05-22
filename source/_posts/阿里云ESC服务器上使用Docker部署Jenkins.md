---
title: 阿里云ESC服务器上使用Docker部署Jenkins
date: 2019-05-19 15:27:22
tags:
---

## Why

突然想起自己还有一台阿里云的服务器，团购的那种，买的时候还不知道突发性实例的坑，买完了才发现，跑CPU需要消耗积分，积分消耗完CPU的能力就被限制到10%，这不是坑爹么！后来降级到了普通的通用型实例，放着也是闲置，正好最近了解到了devOps的概念，正好拿来练练手。

## 步骤

### 首先确保`docker`已安装：

跟着官网的教程，在对应的操作系统上安装`docker`，linux系统记得把`docker-compose`也安装上。

```bash
$ docker --version
Docker version 18.09.6, build 481bc77

$ docker-compose -v
docker-compose version 1.24.0, build 0aa59064
```

### 创建`jenkins`需要的volume：

官方还是更推荐使用`volume`去管理容器使用的硬盘。

```bash
$ docker volume create jenkins
```

### 启动容器：

```bash
$ docker run -d \
--name jenkins \
--mount source=jenkins,target=/var/jenkins_home \
-v $(which docker):/usr/bin/docker \
-v $(which docker-compose):/usr/bin/docker-compose \
-v /var/run/docker.sock:/var/run/docker.sock \
-u root \
-p 8080:8080 \
jenkins/jenkins:lts
```

依次解释下每个参数的含义：

- `run` 启动容器
- `-d` 后台运行容器
- `--name jenkins` 指定容器的名字为`jenkins`
- `--mount source=jenkins,target=/var/jenkins_home` 将刚刚创建的`volume`挂载到容器内的`/var/jenkins_home`目录上，这是`jenkins`的工作目录
- `-v $(which docker):/usr/bin/docker` 允许容器内使用宿主机的`dokcer`
- `-v $(which docker-compose):/usr/bin/docker-compose` 允许容器内使用宿主机的`docker-compose`
- `-v /var/run/docker.sock:/var/run/docker.sock` 允许容器和宿主机的`docker`守护进程通信
- `-u root` 因为要使用宿主机的`docker`所以需要root权限
- `-p 8080:8080` 绑定容器的`8080`端口到宿主机上
- `jenkins/jenkins:lts` `jenkins`的官方镜像

### 查看`jenkins`初始管理员密码：

`jenkins`容器启动后，初始管理员密码就会生成，我们需要它去完成`jenkins`的第一次启动，第一次设置完管理员后这个密码就没用了。

可以进入容器查看初始管理员密码：

```bash
$ docker exec -it jenkins /bin/bash
$ cat /var/jenkins_home/secrets/initialAdminPassword
$ exit # 退出容器
```

或者直接在卷中查看初始管理密码：

```bash
$ cat /var/lib/docker/volumes/jenkins/_data/secrets/initialAdminPassword
```

### 初始化`jenkins`：

打开浏览器访问`8080`，输入初始管理员密码，创建管理员，`jenkins`的安装就完成了。
