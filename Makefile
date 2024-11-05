# Makefile for building CoreDNS
GITCOMMIT?=$(shell git describe --dirty --always)
BINARY:=coredns
SYSTEM:=
CHECKS:=check
BUILDOPTS?=-v
GOPATH?=$(HOME)/go
MAKEPWD:=$(dir $(realpath $(firstword $(MAKEFILE_LIST))))
CGO_ENABLED?=0
GOLANG_VERSION ?= $(shell cat .go-version)
REPO=europe-west3-docker.pkg.dev/blogs-f7fe6/thomas-registry
IMAGE=coredns
CURPWD:=$(shell pwd)

export GOSUMDB = sum.golang.org
export GOTOOLCHAIN = go$(GOLANG_VERSION)

.PHONY: all
all: coredns

.PHONY: coredns
coredns: $(CHECKS)
	CGO_ENABLED=$(CGO_ENABLED) $(SYSTEM) go build $(BUILDOPTS) -ldflags="-s -w -X github.com/coredns/coredns/coremain.GitCommit=$(GITCOMMIT)" -o $(BINARY)

.PHONY: check
check: core/plugin/zplugin.go core/dnsserver/zdirectives.go

core/plugin/zplugin.go core/dnsserver/zdirectives.go: plugin.cfg
	go generate coredns.go
	go get

.PHONY: gen
gen:
	go generate coredns.go
	go get

.PHONY: pb
pb:
	$(MAKE) -C pb

.PHONY: clean
clean:
	go clean
	rm -f coredns

build-by-docker:
	docker run --rm -i -t \
    -v $(CURPWD):/go/src/github.com/coredns/coredns -w /go/src/github.com/coredns/coredns \
        golang:1.21 sh -c 'GOFLAGS="-buildvcs=false" make gen && GOFLAGS="-buildvcs=false" make'

docker-build: build-by-docker coredns
	docker build -t $(REPO)/$(IMAGE):latest .
docker-push:
	docker push $(REPO)/$(IMAGE):latest
docker: docker-build docker-push
