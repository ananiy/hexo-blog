---
title: 在Docker中部署Jenkins
date: 2019-05-19 15:27:22
tags:
---

## 步骤

首先确保`docker`已安装：

```bash
$ docker --version
Docker version 18.09.6, build 481bc77
```

拉一下`jenkins`镜像：

```bash
$ docker pull jenkins/jenkins:lts
```

创建卷：

```bash
$ docker volume create jenkins
```

启动容器：

```bash
$ docker run -d \
--name jenkins \
--mount source=jenkins,target=/var/jenkins_home \
-p 8080:8080 \
-p 50000:50000 \
jenkins/jenkins:lts
```

可以进入容器执行命令：

```bash
$ docker exec -it jenkins /bin/bash
$ cat /var/jenkins_home/secrets/initialAdminPassword
$ exit # 退出容器
```

或者直接在卷中查看初始管理密码：

```bash
$ cat /var/lib/docker/volumes/jenkins/_data/secrets/initialAdminPassword
```
