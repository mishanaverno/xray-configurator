
build-conf:
	docker build --platform linux/amd64 -t xray-conf:latest ./configurator

tag-conf:
	docker tag xray-conf:latest mishanaverno/xray-conf:latest

run-conf: build-conf
	docker run --rm --network host -v /Users/monipchenko/work/vol:/usr/share/xray/ xray-conf:latest

run-tty-conf:
	docker run --rm -it \
  --entrypoint sh \
  -v /Users/monipchenko/work/vol:/usr/share/xray \
  xray-conf:latest

push-conf: build-conf tag-conf
	docker login -u mishanaverno
	docker push mishanaverno/xray-conf:latest

build-bot:
	docker build --platform linux/amd64 -t xray-bot:latest ./bot

run-bot: build-bot
	docker run --rm --env-file=/Users/monipchenko/work/vpn-conf/test/bot.env -v /Users/monipchenko/work/vpn-conf/utils/xr-conf.sh:/usr/bin/xr-conf:ro xray-bot:latest

tag-bot:
	docker tag xray-bot:latest mishanaverno/xray-bot:latest

push-bot: build-bot tag-bot
	docker login -u mishanaverno
	docker push mishanaverno/xray-bot:latest
