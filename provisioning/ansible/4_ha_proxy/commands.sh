
sudo cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.bak
sudo vim /etc/haproxy/haproxy.cfg


sudo systemctl reload haproxy
sudo ss -tulnp | grep 5601