rm -rf build-src-deb
mkdir build-src-deb
cp -ar \
  CMakeLists.txt    \
  AUTHORS           \
  README            \
  bashcompletion    \
  src               \
  icons             \
  debian            \
  qml               \
  qmlcompletionbox  \
  data              \
  build-src-deb
cd build-src-deb
dpkg-buildpackage -sa -S -uc -us
cd ..
rm -rf build-src-deb
