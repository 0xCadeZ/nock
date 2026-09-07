.PHONY: app run clean icon adapter

app:
	./scripts/package_app.sh

run: app
	open build/Nock.app

icon:
	./scripts/make_icon.sh

adapter:
	./scripts/build_adapter.sh

clean:
	rm -rf .build build/Nock.app
