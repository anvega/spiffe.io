HUGO_VERSION ?= 0.68.3

setup:
	npm install

serve: pull-external-content
	HIDE_RELEASES=true BRANCH=local hugo server \
		--buildDrafts \
		--buildFuture \
		--disableFastRender \
		--ignoreCache \
		--noHTTPCache

serve-with-releases: pull-external-content
	hugo server \
		--buildDrafts \
		--buildFuture \
		--disableFastRender

production-build: pull-external-content
	hugo \
		--gc \
		--ignoreCache

preview-build: pull-external-content
	hugo \
		--gc \
		--ignoreCache \
		--baseURL $(DEPLOY_PRIME_URL)

docker-build:
	docker build . \
		--rm \
		-t spiffe.io:latest \
		-f Dockerfile.dev

docker-serve:
	docker run --rm -it \
		-v $(PWD):/app \
		-p 1313:1313 \
		-e HIDE_RELEASES=true \
		spiffe.io:latest

docker-serve-with-releases:
	docker run --rm -it \
		-v $(PWD):/app \
		-p 1313:1313 \
		spiffe.io:latest

pull-external-content:
	python ./pull_external.py