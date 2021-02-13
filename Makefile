ASSETS := $(shell yq e '.assets.[].src' manifest.yaml)
ASSET_PATHS := $(addprefix assets/,$(ASSETS))

.DELETE_ON_ERROR:

all: mastodon.s9pk

install: mastodon.s9pk
	appmgr install mastodon.s9pk

mastodon.s9pk: manifest.yaml config_spec.yaml config_rules.yaml image.tar instructions.md $(ASSET_PATHS)
	appmgr -vv pack $(shell pwd) -o mastodon.s9pk
	appmgr -vv verify mastodon.s9pk

image.tar: Dockerfile docker_entrypoint.sh nginx.conf mastodon
	DOCKER_CLI_EXPERIMENTAL=enabled docker buildx build --tag start9/mastodon --platform=linux/arm/v7 -o type=docker,dest=image.tar .