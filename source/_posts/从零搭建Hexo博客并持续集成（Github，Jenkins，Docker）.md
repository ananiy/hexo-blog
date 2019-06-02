---
title: 从零搭建Hexo博客并持续集成（Github，Jenkins，Docker）
date: 2019-06-01 11:26:18
tags:
---

## 闲言碎语

首先祝大家儿童节快乐！

这应该算的上我真正意义的第一篇博客（第一篇用Docker搭建Jenkins是拿来测试博客的:D）。毕业快一年了，一直在瞎提升自己，没有真正的记录下整个过程。最近慢慢感觉到处于了一个瓶颈期，不知道怎么突破，思前想后，还是觉得应该从基础出发，加深自己对某个技术的理解，而不是走马观花，匆匆过一遍文档，写几个demo，就好像自己掌握了一样。

从大学兴趣使然入了前端的坑开始，到后来用nodejs写一些简单的后端应用，总觉得作为一个开发，还缺少点什么。直到打开[roadmap](https://roadmap.sh/)，发现除了前端后端，还有一个方向叫做DevOps。

引用下维基百科的介绍：

> DevOps（Development和Operations的组合词）是一种重视“软件开发人员（Dev）”和“IT运维技术人员（Ops）”之间沟通合作的文化、运动或惯例。透过自动化“软件交付”和“架构变更”的流程，来使得构建、测试、发布软件能够更加地快捷、频繁和可靠。

在DevOps的roadmap中，container和CI、CD都是必学的概念，其中的最流行的工具分别是docker和jenkins。

最近vscode发布了remote系列插件，可以用vscode打开ssh，wsl，container上的文件夹了，还可以使用vscode本身的插件。这是要告别ssh到服务器vim编写代码的时代了吗？ssh和wsl都在日常的使用中很常见，container的概念对我来说倒是很模糊，一直没什么机会去了解，正好借着搭建blog的机会学习一下docker，顺便与jenkins结合使用CI，达到自动化部署上线的目的。

首先捋清楚每个概念：

2. GitHub：git远程仓库，用来管理项目代码
3. Docker：容器化工具，用来打包，部署项目
4. Jenkins：持续集成工具，用来推送代码后自动完成打包、部署

下面开始介绍每个部分怎么完成，过于基础的步骤就略过了。

## 创建hexo项目

### 开发环境

hexo的项目主要还是依赖node的环境，为了部署也需要git。开发尽量还是在类unix系统下进行（如果是在windows下，可以使用wsl，也可以用docker跑一个ubuntu之类的容器）。一行命令装上nvm，再装个8或10的lts版node，再全局装个`hexo-cli`的npm包：`npm install hexo-cli -g`，就完成了开发环境的搭建。

### 初始化项目

```bash
$ hexo init <folder>
```

emmm，好像也没什么好说的，这块重点说一下[hexo-next](https://github.com/theme-next/hexo-theme-next)主题吧，这个主题本身是一个git仓库，如果直接clone到theme/next文件夹的话，项目推到github是不包括theme/next文件夹的，搜了一下网上的解决办法主要有两种：第一种是删掉.git文件夹，当成普通的文件来处理，这种方法简单，坏处是一下子多了300个左右的主题文件，以后更新主题也比较麻烦；第二种是把主题仓库当作submodule，这样以后再打包的时候初始化好submodule就好了，更新也很方便。

```bash
$ git submodule add https://github.com/theme-next/hexo-theme-next themes/next
```

ps：从远程仓库clone下项目后记得初始化submodule。

像个人博客这种项目直接推master分支发版就够了，如果是更大的项目还是得用别的分支开发，然后合master分支打tag的方式发版。

## 使用docker打包，部署

docker安装和使用还是得去按照官网的文档来，理解清楚每个概念就行。这里我们需要构建自己的项目镜像，需要使用node镜像，在node里完成build，然后将生成的public文件夹拷贝到nginx镜像。在项目根目录新建`DockerFile`文件:

```docker
FROM node:8-alpine as builder
WORKDIR /app
COPY . .
RUN npm i && npm run build
FROM nginx:alpine
COPY --from=builder /app/public /usr/share/nginx/html
```

依次介绍下每一行：

- 从远程仓库拉一个node镜像，版本号是8-alpine。alpine是一个linux的发行版，特点是体积小，因此基于它的镜像体积也是很小的，把这个镜像作为打包镜像，重命名为builder。
- 指定工作目录为/app，这样就直接导致容器的当前目录是/app了。
- 从当前目录拷贝文件到容器的工作目录，注意容器的当前目录已经被我们指定为/app了，所以直接用两个`.`是没问题的。
- 安装项目本身的依赖，并且执行打包，注意这个过程是在容器里进行的，容器本身是没有hexo的全局包的，所以这里我写了个npm脚本，使用项目本身的hexo包。
- 再从远程仓库拉一个nginx镜像，这个镜像用来启动web服务，这样最后生成的容器是很干净的，没有多余的node。
- 把打包完的public文件夹复制到nginx的默认根目录下。

我们可以根据这个配置文件，在项目根目录运行以下命令，生成我们的项目镜像（`-t`参数全称tag, 给我们的镜像打一个标签，相当于起个名字）：

```bash
$ docker build -t hexo-blog .
```

根据该镜像启动容器：

```bash
$ docker run -d --name hexo-blog hexo-blog
```

这样我们就能根据我们的镜像生成一个容器并运行啦。但这样还不够，我们每次推送代码，都需要重新构建镜像，生成容器并运行。如何简化这个流程？答案是用`docker-compose`，可以将当前项目做为一个service运行，自动构建镜像启动容器。

我们在项目根目录新建一个`docker-compose.yml`配置文件：

```yml
version: '3'
services:
  blog:
    container_name: hexo-blog
    build: .
    image: hexo-blog
    ports:
      - '80:80'
      - '443:443'
    volumes:
      - nginx:/etc/nginx/conf.d
    networks:
      - nginx
volumes:
  nginx:
networks:
  nginx:
```

这个配置文件也很好理解，使用docker-compose第三个版本的配置文件，有一个service，一个volume用来挂载nginx的配置文件（方便配https），一个network虚拟网卡给nginx使用（其实没必要的）。

service的配置和之前的手动敲的命令做的事情差不多，build源是当前项目，指定镜像名和容器名，和宿主机绑定80和443端口，指定使用的volume和network。

然后我们就可以使用一行命令，创建镜像生成容器并运行啦：

```bash
$ docker-compose up --build -d
```

## 配置jenkins

现在我们可以假定这样一个流程：编写博客，推送到github，然后自己的服务器把代码pull下来，用docker-compose启动服务。

怎样自动化这个过程呢？我们需要jenkins持续集成工具。jenkins的安装我的上一篇blog有写，这里就不做说明了。

### 给jenkins安装github插件

如果是默认安装的话其实已经自带了，所以我们只需要配置一遍。

打开jenkins的系统管理 -> 系统设置，找到github选项，添加一个github服务器，记得添加一个[github Personal access tokens](https://github.com/settings/tokens)，API URL填：`https://api.github.com`，名称随意，我填的github，选上管理hook，点击测试连接会显示：Credentials verified。

### 新建jenkins任务

- 点击新建任务
- 输入任务名称：hexo-blog
- 选择：构建一个自由风格的软件项目
- 源码管理选git，输入github仓库地址
- 如果使用了之前的next主题，勾选：Additional Behaviours，选择：Recursively update submodules
- 构建触发器选择：GitHub hook trigger for GITScm polling
- 构建选择执行shell：docker-compose up --build -d
- 点击保存任务

## 测试

本地`hexo n <blog title>`，commit后push代码，观察jenkins的构建，并访问网站观察是否成功。

## 总结

其实整个流程还是很简单的，主要是很多点需要自己弄明白具体做了什么事情，代码编写，打包，部署，然后自动化整个流程。工具与工具之间的配套使用，我觉得是一个稍微难的点，很多时候我们得到了正确的结果，却是歪打误着造成的。所以一定要关注整个过程，是否和自己想的一样。
