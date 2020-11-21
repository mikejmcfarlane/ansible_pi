# enable I2C
sudo raspi-config

sudo apt install -y wiringpi python3-pip libopenjp2-7 python3-libtiff libtiff5 libatlas-base-dev p7zip-full
sudo python3 -m pip install pillow numpy RPi.GPIO

cd
wget https://project-downloads.drogon.net/wiringpi-latest.deb
sudo dpkg -i wiringpi-latest.deb
gpio -v

cd
wget http://www.airspayce.com/mikem/bcm2835/bcm2835-1.60.tar.gz
tar zxvf bcm2835-1.60.tar.gz 
cd bcm2835-1.60/
sudo ./configure 
sudo make && sudo make check && sudo make install

cd
wget https://www.waveshare.com/w/upload/b/b7/PoE_HAT_B_code.7z
7z x PoE_HAT_B_code.7z -r -o./PoE_HAT_B_code
cd PoE_HAT_B_code/c/
make clean
make
# sudo ./main


vi /etc/rc.local
# insert before exit
/home/pi/PoE_HAT_B_code/c/main &

sudo reboot

# test
while true; do vcgencmd measure_clock arm; vcgencmd measure_temp; sleep 10; done& stress -c 4 -t 900s

