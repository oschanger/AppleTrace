cd hookzz
make
cd ..
cp hookzz/build/ios-arm64/libhookzz.static.a appletrace/appletrace/src/objc/hookzz/
cp hookzz/include/hookzz.h appletrace/appletrace/src/objc/hookzz/