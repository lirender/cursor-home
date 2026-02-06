.PHONY: macos-app macos-dmg linux-deb linux-tarball clean

macos-app:
	@bash platforms/macos/scripts/build-app.sh

macos-dmg:
	@bash platforms/macos/scripts/build-dmg.sh

linux-deb:
	@bash platforms/linux/scripts/build-deb.sh

linux-tarball:
	@bash platforms/linux/scripts/build-tarball.sh

clean:
	rm -rf platforms/macos/build
	rm -rf platforms/linux/build
