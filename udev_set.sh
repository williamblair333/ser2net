cp config/z21_persistent-local.rules /etc/udev/rules.d/z21_persistent-local.rules
udevadm control --reload-rules && sudo udevadm trigger
/opt/docker/comms-infra-back/containers/ser2net/ser2net_chmod_ttyUSB.sh
ls -lah /dev/ttyU*
ls -lah /dev/ttyU* | wc -l; ls -lah /dev/usb*
ls -lah /dev/usb* | wc -l
