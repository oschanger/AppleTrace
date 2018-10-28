
rm -rf hookzz
mkdir hookzz
cd hookzz

git clone --depth 1 git@github.com:jmpews/HookZz.git

cd HookZz/

rm -rf .git

cd cmake

cmake .. -G "Unix Makefiles" \
-DCMAKE_TOOLCHAIN_FILE=cmake/ios.toolchain.cmake \
-DIOS_PLATFORM=OS \
-DIOS_ARCH=arm64 \
-DENABLE_ARC=FALSE \
-DENABLE_BITCODE=OFF \
-DDEBUG=ON \
-DSHARED=OFF \
-DPLATFORM=iOS \
-DARCH=armv8 \
-DCMAKE_VERBOSE_MAKEFILE=ON -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DCMAKE_BUILD_TYPE=Release


make -j4

cd ../../../

cp hookzz/HookZz/cmake/libhookzz.a appletrace/appletrace/src/objc/hookzz/
cp hookzz/HookZz/include/hookzz.h appletrace/appletrace/src/objc/hookzz/

echo "Done."

