
build:
	docker build --platform linux/amd64 -t xray-conf:latest .

tag:
	docker tag xray-conf:latest mishanaverno/xray-conf:latest

run: build
	docker run --network host -v /Users/monipchenko/work/vol:/usr/share/xray/ xray-conf:latest

run-tty:
	docker run --rm -it \
  --entrypoint sh \
  -v /Users/monipchenko/work/vol:/usr/share/xray \
  xray-conf:latest

push: build tag
	docker login -u mishanaverno
	docker push mishanaverno/xray-conf:latest
