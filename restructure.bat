@echo off
if not exist backend mkdir backend
if exist src move src backend\src
if exist package.json move package.json backend\
if exist package-lock.json move package-lock.json backend\
if exist .env move .env backend\
if exist render.yaml move render.yaml backend\
if exist DEPLOYMENT.md move DEPLOYMENT.md backend\
if exist scripts move scripts backend\scripts
if exist make_admin.js move make_admin.js backend\
if exist trigger_feed.js move trigger_feed.js backend\
if exist node_modules move node_modules backend\node_modules
echo Restructure finished > restructure_log.txt
