.PHONY: test test-unit test-integration build deploy clean help

SCHEME = VerboTests
PROJECT = Verbo.xcodeproj
CONFIG = Debug
XCPRETTY := $(shell command -v xcpretty 2>/dev/null)

ifdef XCPRETTY
  FORMATTER = | xcpretty
else
  FORMATTER = | tail -20
endif

build: ## Generate project and build
	xcodegen generate
	xcodebuild -project $(PROJECT) -scheme Verbo -configuration $(CONFIG) build 2>&1 $(FORMATTER)

test: build ## Run all tests
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) \
		-skip-testing:VerboTests/TextOutputServiceTests \
		2>&1 $(FORMATTER)

test-unit: build ## Run unit tests only (fastest)
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) \
		-only-testing:VerboTests/AppConfigTests \
		-only-testing:VerboTests/SceneTests \
		-only-testing:VerboTests/PipelineStateTests \
		-only-testing:VerboTests/HistoryRecordTests \
		-only-testing:VerboTests/IFlytekSTTAdapterTests \
		-only-testing:VerboTests/OpenAILLMAdapterTests \
		-only-testing:VerboTests/PipelineEngineTests \
		2>&1 $(FORMATTER)

test-integration: build ## Run unit + integration tests
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) \
		-skip-testing:VerboTests/TextOutputServiceTests \
		2>&1 $(FORMATTER)

deploy: build ## Build and deploy to /Applications
	pkill -f "Verbo.app/Contents/MacOS/Verbo" 2>/dev/null || true
	rm -rf /Applications/Verbo.app
	cp -R $$(find ~/Library/Developer/Xcode/DerivedData -name "Verbo.app" -path "*/Debug/*" -maxdepth 5 | head -1) /Applications/Verbo.app
	open /Applications/Verbo.app

clean: ## Clean build artifacts
	xcodebuild -project $(PROJECT) -scheme Verbo clean 2>&1 $(FORMATTER)
	rm -rf ~/Library/Developer/Xcode/DerivedData/Verbo-*

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
