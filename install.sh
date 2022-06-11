mkdir -p build
cd build
cmake ..
sudo make install
cd ..

for x in email.pl email-search.pl smtp-cli smtp-oauth email-gui.py; do
  sudo rm -f /usr/local/bin/$x
  sudo ln -s /opt/qtemail/bin/$x /usr/local/bin/
done
