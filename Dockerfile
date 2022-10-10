## it uses node js image alpine version from image registries.
FROM node:18.6-alpine3.15
## it sets directory in the container to /app to store files and launch our app.
WORKDIR /app
## it copies the app to /app directory with dependencies.
COPY package.json /app
RUN npm install
COPY . /app
## it commands to run our app which is app.js.
CMD node app.js
##  it exposes the port where our app is running that is port 3000.
EXPOSE 3000
