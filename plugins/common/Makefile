GOARCH ?= amd64
TRIGGERS = triggers/app-list triggers/core-post-deploy triggers/install triggers/post-delete
BUILD = prop common triggers
PLUGIN_NAME = common

clean-prop:
	rm -rf prop

clean-common:
	rm -rf common

prop: clean-prop **/**/prop.go
	GOARCH=$(GOARCH) go mod tidy
	GOARCH=$(GOARCH) go build -ldflags="-s -w" $(GO_ARGS) -o prop src/prop/prop.go

common: clean-common **/**/common.go
	GOARCH=$(GOARCH) go mod tidy
	GOARCH=$(GOARCH) go build -ldflags="-s -w" $(GO_ARGS) -o common src/common/common.go

include ../../common.mk
