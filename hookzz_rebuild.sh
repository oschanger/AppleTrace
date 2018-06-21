
cd hookzz
rm -rf build

mkdir build

cd build
cmake .. -DCMAKE_TOOLCHAIN_FILE=../cmake/ios.toolchain.cmake -DIOS_PLATFORM=OS -DIOS_ARCH=arm64 -DENABLE_ARC=FALSE -DZPLATFORM=iOS -DZARCH=arm64
make

cd ..
cd ..
cp hookzz/build/libhookzz.a appletrace/appletrace/src/objc/hookzz/
cp hookzz/include/hookzz.h appletrace/appletrace/src/objc/hookzz/
