# 创建应用
运行Docker官方演示开始项目 
`docker run -d -p 80:80 --name docker-getting-started docker/getting-started`
打开 http://localhost  可以看到文档
下载 应用代码 http://localhost/assets/app.zip
此处使用 nodejs 项目（app.zip）作为演示

## 新建一个新的容器镜像
1. 在 `package.json` 同一目录新建 `Dockerfile`
```Dockerfile
FROM node:12-alpine
WORKDIR /app
COPY . .
RUN yarn install --production
CMD ["node", "/app/src/index.js"]
```
FROM指定要使用的源镜像，WORKDIR指定容器内的工作目录，COPY当前目录的内容到容器内的工作目录，然后RUN在容器内执行命令，最后CMD执行命令启动容器

2. 构建镜像
在 `Dockerfile` 同路径 执行命令：
```shell
docker build -t getting-started .
```
该命令会使用 `Dockerfile` 构建镜像，
- -t ：指定要创建的目标镜像名
- . ：`Dockerfile` 文件所在目录，可以指定`Dockerfile` 的绝对路径

## 使用创建的镜像运行一个容器
```shell
docker run -dp 3000:3000 --name app-test getting-started
```
-d 指定容器在后台运行 -p指定端口映射 主机端口:容器内端口 --name 指定容器名称

## 更新应用（镜像）
修改APP代码，如果要看到效果，需要：
1. 重新构建镜像 
`docker build -t getting-started .`
2. 删除已运行的容器
查询已运行的所有容器：`docker ps` 或者 `docker ps -a`查询所有容器
停止容器：`docker stop <the-container-id>`
删除容器: `docker rm <the-container-id>`
或者强制删除运行中的容器：`docker rm -f <the-container-id>`
3. 再次运行容器
`docker run -dp 3000:3000 --name app-test getting-started`

# 持久化数据

使用同一个镜像运行的两个或多个容器的文件系统是相互独立的，一个容器内的改动在另外一个容器中是不可见的。
Docker使用 卷（volumes）将容器的特定文件系统路径连接回主机的能力，这样容器内改变在主机系统上是可见的，如果另外一个容器挂载到这个卷也是可以看到这些文件的。

## 命名卷
命名卷可以看作是一个简单的数据桶。Docker维护磁盘上的物理位置，您只需记住卷的名称。每次使用卷时，Docker都会确保提供正确的数据。
1. 创建命名卷
```shell
docker volume create todo-db
```
2. 启动容器，使用 -v 指定券名
```shell
docker run -dp 3000:3000 -v todo-db:/etc/todos --name app-test getting-started
```
-v 格式：要使用的卷名:容器内挂载到的文件

# 绑定挂载（Bind Mounts）
处于开发应用状态时，使用绑定挂载 将主机上的源代码 挂载到 容器中，这样 在本机上修改代码时 容器也能获得更改
## 启动一个开发模式的容器
```shell
docker run -dp 3000:3000 `
    -w /app -v ${PWD}:/app `
    --name app-test `
    node:12-alpine `
    sh -c "yarn install && yarn run dev"
```
- 注意 linux 中命令换行用 \ ,windows的 PowerShell 的换行是 `
- -w 指定容器的工作目录（working_dir）
- -v ${PWD}:/app， ${PWD}指当前目录 挂载到 容器内的/app目录
- node:12-alpine 是要使用的镜像
- sh -c 是在容器内执行命令（alpine系统 没有bash 只有 sh） `yarn install && yarn run dev`， dev 使用 nodemon 监控文件系统的改变并重启项目

在本地开发设置中，使用绑定挂载非常常见。优点是开发机器不需要安装所有的构建工具和环境。通过一个docker run命令，dev环境就可以启动了。

# 多容器应用
上面的应用容器 包含一个 SQLLite数据库，实际应用会使用Mysql之类的大型数据库，Docker 一般要求数据服务应该单独运行在一个容器中。
APP运行在一个容器中、数据库(mysql)运行在一个容器中。

## 容器网络
多容器之间通讯使用网络(Network)。（记住如果两个容器在同一个网络上他们就可以互通联系，反之则不能）

## 启动MYSQL
1. 创建网络 network
```shell
docker network create todo-app
```
2. 启动Mysql
```shell
docker run -d `
    --network todo-app --network-alias mysql `
    --name todo-mysql `
    -v todo-mysql:/var/lib/mysql `
    -e MYSQL_ROOT_PASSWORD=secret `
    -e MYSQL_DATABASE=todos `
    mysql:5.7 --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci
```
- --network 指定使用上面创建的网络 todo-app，并且 --network-alias docker会将网络别名解析到容器的IP
- -v 指定 卷 todo-mysql 挂载到 容器内 /var/lib/mysql（注意这里不用提前创建卷，docker会自动创建）
- -e 指定一些环境变量用来初始化 mysql 容器

3. 进入mysql
```shell
docker exec -it <mysql-container-id> mysql -p
```
进入mysql可看到 数据库名todos已创建

## 使用MySQL启动APP
APP应用支持一些环境变量：
- MYSQL_HOST - the hostname for the running MySQL server
- MYSQL_USER - the username to use for the connection
- MYSQL_PASSWORD - the password to use for the connection
- MYSQL_DB - the database to use once connected
注意：开发环境可以使用环境变量，但是生产环境不建议使用（正常方式应该将这些敏感信息存放到系统配置文件中进行加载）
```shell
docker run -dp 3000:3000 `
  -w /app -v ${PWD}:/app `
  --network todo-app `
  --name app-test `
  -e MYSQL_HOST=mysql `
  -e MYSQL_USER=root `
  -e MYSQL_PASSWORD=secret `
  -e MYSQL_DB=todos `
  node:12-alpine `
  sh -c "yarn install && yarn run dev"
```
注意：-e MYSQL_HOST=mysql 使用的是网络别名即上面mysql容器 --network-alias指定的别名

## 总结以上
这些过程是繁琐的，我们必须先准备好所有后才能开始启动项目，包括创建网络network、启动容器、传递环境变量、暴露端口、设置卷等等，非常繁琐，也不便于将项目移交给另外一个人。
使用Docker Compose 可以简化这些步骤，一个命令完成安装部署。

# Docker Compose
Docker Compose 主要用于定义和分享多容器应用的工具。使用 YAML文件来组织所有服务，可以做到一键启动或关闭所有。

## 安装Docker Compose
Windows和Mac下安装了 Docker Desktop/Toolbox，Docker Compose也一并安装了。
Linux下 按照文档 https://docs.docker.com/compose/install/ 安装.
查看安装：
`docker-compose version`

## 创建Compose文件
1. 在项目根目录创建 文件 docker-compose.yml
2. 定义版本，查看 https://docs.docker.com/compose/compose-file/ 和 本地docker版本（命令：`docker version`）
```yml
version: "3.8"
```
3. 定义服务（容器）
```yml
version: "3.8"
services:
    app: # 服务名称，任意取，会据此生成网络别名(network alias)
        image: node:12-alpine # 使用的镜像
        container_name: nodejs-todo-app
        command: sh -c "yarn install && yarn run dev" # 容器内执行的命令（sh -c "yarn install && yarn run dev）
        ports: # HOST:CONTAINER 端口映射 数组 https://docs.docker.com/compose/compose-file/#short-syntax-1
            - 3000:3000 #（-p 3000:3000）
        working_dir: /app # 容器内的工作目录（-w /app）
        volumes: # 卷 https://docs.docker.com/compose/compose-file/#short-syntax-3
            - ./:/app # ./ 表示主机当前目录挂载到容器内目录/app（-v ${PWD}:/app）
        environment: # 环境变量
            MYSQL_HOST: mysql
            MYSQL_USER: root
            MYSQL_PASSWORD: secret
            MYSQL_DB: todos
     mysql: # 数据库服务，它会自动获取网络别名(network alias)
        image: mysql:5.7
        container_name: todo-mysql
        volumes:
            - todo-mysql:/var/lib/mysql # 命名卷不会自动创建，所以要在下面创建
        environment: 
            MYSQL_ROOT_PASSWORD: secret
            MYSQL_DATABASE: todos
volumes:
    todo-mysql: # 命名卷名称 app_todo-mysql-data
```
## 运行应用栈
先确保上面的容器服务已经删除（防止端口占用的情况）。

```shell
docker-compose up -d
```
-d 表示后台启动

注意：APP启动时会连接数据库3306端口，而mysql不一定能在它之前启动好，所以APP需要等待3306端口准备好，这里的NodeJS应用使用了 `wait-port` 依赖来实现等待端口，其他语言的框架也应该有类似的工具。

## 移除应用栈
```shell
docker-compose down
```
这会移除所有容器，网络也会一并移除，但是卷不会移除，可以 加 --volumes 移除卷
```shell
docker-compose down --volumes
```
