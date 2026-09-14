.PHONY: app run test clean icon adapter

app:
	./scripts/package_app.sh

run: app
	open build/Nock.app

# XCTest/Testing ship with Xcode, not the Command Line Tools; point SwiftPM at Xcode when needed.
test:
	DEVELOPER_DIR=$${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer} swift test

icon:
	./scripts/make_icon.sh

adapter:
	./scripts/build_adapter.sh

clean:
	rm -rf .build build/Nock.app
