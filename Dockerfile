ARG DEBIAN_IMAGE=debian:stable-slim
ARG BASE=gcr.io/distroless/static-debian11:nonroot

FROM golang:1.21-alpine AS builder
RUN apk add --no-cache git
RUN apk add --no-cache make
WORKDIR /go/src/app
COPY . .

RUN go get -d -v ./...
ENV GOFLAGS="-buildvcs=false"
RUN GOFLAGS="-buildvcs=false" make gen && GOFLAGS="-buildvcs=false" make
RUN ls -l

FROM --platform=$BUILDPLATFORM ${DEBIAN_IMAGE} AS build
SHELL [ "/bin/sh", "-ec" ]

RUN export DEBCONF_NONINTERACTIVE_SEEN=true \
           DEBIAN_FRONTEND=noninteractive \
           DEBIAN_PRIORITY=critical \
           TERM=linux ; \
    apt-get -qq update ; \
    apt-get -yyqq upgrade ; \
    apt-get -yyqq install ca-certificates libcap2-bin; \
    apt-get clean
COPY --from=builder /go/src/app/coredns /coredns

RUN setcap cap_net_bind_service=+ep /coredns

FROM --platform=$TARGETPLATFORM ${BASE}
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=build /coredns /coredns
COPY CoreFile /CoreFile

USER nonroot:nonroot
EXPOSE 53 53/udp
ENTRYPOINT ["/coredns"]
