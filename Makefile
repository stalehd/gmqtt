# Basic Makefile for Golang project
# Includes GRPC Gateway, Protocol Buffers
SERVICE		?= $(shell basename `go list`)
VERSION		?= $(shell git describe --tags --always --dirty --match=v* 2> /dev/null || cat $(PWD)/.version 2> /dev/null || echo v0)
PACKAGE		?= $(shell go list)
PACKAGES	?= $(shell go list ./...)
FILES		?= $(shell find . -type f -name '*.go' -not -path "./vendor/*")
BUILD_DIR	?= build

# Binaries
PROTOC		?= protoc

.PHONY: help clean fmt lint vet test test-cover build build-docker all

default: help

# show this help
help:
	@echo 'usage: make [target] ...'
	@echo ''
	@echo 'targets:'
	@egrep '^(.+)\:\ .*#\ (.+)' ${MAKEFILE_LIST} | sed 's/:.*#/#/' | column -t -c 2 -s '#'

# clean, format, build and unit test
all:
	make clean-all
	make gofmt
	make build
	make test

# build and install go application executable
install:
	go install -v ./...

# Print useful environment variables to stdout
env:
	echo $(CURDIR)
	echo $(SERVICE)
	echo $(PACKAGE)
	echo $(VERSION)

# go clean
clean:
	go clean

# remove all generated artifacts and clean all build artifacts
clean-all:
	go clean -i ./...
	rm -fr build

# fetch and install all required tools
tools:
	go get -u golang.org/x/tools/cmd/goimports
	go get -u github.com/golang/lint/golint
	go get github.com/golang/mock/mockgen@v1.4.4
	# Reqire when adding proto and grpc compilation

# format the go source files
fmt:
	goimports -w $(FILES)

# run go lint on the source files
lint:
	golint $(PACKAGES)

 # run go vet on the source files
vet:
	go vet ./...

# generate mock code
generate-mocks:
	@./mock_gen.sh

go-generate:
	go generate ./...


# generate mocks and run short tests
test: generate-mocks
	go test -v -race ./...

# run benchmark tests
test-bench: generate-mocks
	go test -bench ./...

# Generate test coverage
# Run test coverage and generate html report
test-cover:
	rm -fr coverage
	mkdir coverage
	go list -f '{{if gt (len .TestGoFiles) 0}}"go test -covermode count -coverprofile {{.Name}}.coverprofile -coverpkg ./... {{.ImportPath}}"{{end}}' ./... | xargs -I {} bash -c {}
	echo "mode: count" > coverage/cover.out
	grep -h -v "^mode:" *.coverprofile >> "coverage/cover.out"
	rm *.coverprofile
	go tool cover -html=coverage/cover.out -o=coverage/cover.html

test-all: test test-bench test-cover

# Build Golang application binary with settings to enable it to run in a Docker scratch container.
binary: go-generate
	CGO_ENABLED=0 GOOS=linux go build  -ldflags '-s' -o $(BUILD_DIR)/gmqttd ./cmd/gmqttd

build-docker:
	docker build -t gmqtt/gmqttd .
