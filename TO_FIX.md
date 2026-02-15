check ip command / output in p1 correction ip a show $(ip route | grep default | awk '{print $5}')"

