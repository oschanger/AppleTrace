
cd hookzz
rm -rf build

mkdir build
make clean
make BACKEND=ios ARCH=arm64

cd ..
cp hookzz/build/libhookzz.static.a appletrace/appletrace/src/objc/hookzz/
cp hookzz/include/hookzz.h appletrace/appletrace/src/objc/hookzz/
