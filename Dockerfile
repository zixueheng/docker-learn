FROM node:12-alpine
WORKDIR /app
# 先拷贝下面两个文件
COPY package.json yarn.lock ./ 
# 然后执行安装依赖
RUN yarn install --production
# 再拷贝所有文件（但是排除了 node_modules）
COPY . .
CMD ["node", "/app/src/index.js"]