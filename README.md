**Proyect diagram**: 
```bash
Client
   │
   ▼
Varnish (80)
   │
   ▼
Nginx (8080)
   │
   ├── static files
   │
   └── php-fpm (FastCGI)
          │
          ▼
       memcached
```

## Install
```bash
apt install -yqq \
nginx \
php-fpm \
php-cli \
php-memcached \
memcached \
varnish
```

## Check versions
```bash
varnishd -V
varnishd (varnish-7.5.0 revision eef25264e5ca5f96a77129308edb83ccf84cb1b1)
Copyright (c) 2006 Verdens Gang AS
Copyright (c) 2006-2024 Varnish Software
Copyright 2010-2024 UPLEX - Nils Goroll Systemoptimierung


nginx -v
nginx version: nginx/1.26.0 (Ubuntu)


memcached --version
memcached 1.6.29

php-fpm8.3 --version
PHP 8.3.11 (fpm-fcgi) (built: Mar 18 2025 19:13:26)
Copyright (c) The PHP Group
Zend Engine v4.3.11, Copyright (c) Zend Technologies
    with Zend OPcache v8.3.11, Copyright (c), by Zend Technologies
```

## Basic config

### NGINX
```bash
/etc/nginx/sites-available/default
server {
    listen 8080 default_server;
    listen [::]:8080 default_server;

    server_name _;
    root /var/www/html;
    index index.php index.html index.htm;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}

cat >/var/www/html/index.php <<'EOF'
<?php
echo "php-fpm backend OK\n";
EOF
```

### PHP-FPM
```bash
/etc/php/8.3/fpm/pool.d/www.conf
listen = /run/php/php8.3-fpm.sock
```


### MEMCHACHED
```bash
/etc/memcached.conf
# memory
-m 256

# Default connection port is 11211
-p 11211
```


### VARNISH
```bash
/etc/varnish/default.vcl
# 4.0 or 4.1 syntax.
vcl 4.1;

# Default backend definition. Set this to point to your content server.
backend default {
    .host = "127.0.0.1";
    .port = "8080";
}

/etc/default/varnish
DAEMON_OPTS="-a :80 \
             -T localhost:6082 \
             -f /etc/varnish/default.vcl"

cat /usr/lib/systemd/system/varnish.service
[Unit]
Description=Varnish Cache, a high-performance HTTP accelerator
Documentation=https://www.varnish-cache.org/docs/ man:varnishd

[Service]
Type=exec
LimitNOFILE=131072
LimitMEMLOCK=85983232
ExecStart=/usr/sbin/varnishd \
          -F \
          -a :80 \
          -T localhost:6082 \
          -f /etc/varnish/default.vcl \
          -S /etc/varnish/secret \
          -s malloc,256m
```

```bash
systemctl restart memcached php8.3-fpm nginx varnish


systemctl status memcached php8.3-fpm nginx varnish

● memcached.service - memcached daemon
     Loaded: loaded (/usr/lib/systemd/system/memcached.service; enabled; preset: enabled)
     Active: active (running) since Sun 2026-03-08 10:25:43 UTC; 21s ago
 Invocation: 0196557d2d1d459eb13e369d33082398
       Docs: man:memcached(1)
   Main PID: 9220 (memcached)
      Tasks: 10 (limit: 1882)
     Memory: 1.8M (peak: 2M)
        CPU: 57ms
     CGroup: /system.slice/memcached.service
             └─9220 /usr/bin/memcached -m 256 -p 11211 -u memcache -l 127.0.0.1 -l ::1 -P /var/run/memcached/memcached.pid

Mar 08 10:25:43 ub24base02 systemd[1]: Started memcached.service - memcached daemon.


● php8.3-fpm.service - The PHP 8.3 FastCGI Process Manager
     Loaded: loaded (/usr/lib/systemd/system/php8.3-fpm.service; enabled; preset: enabled)
     Active: active (running) since Sun 2026-03-08 10:25:43 UTC; 21s ago
 Invocation: ee8c0b5879f74d928014259c3f13d978
       Docs: man:php-fpm8.3(8)
    Process: 9197 ExecStartPost=/usr/lib/php/php-fpm-socket-helper install /run/php/php-fpm.sock /etc/php/8.3/fpm/pool.d/www.conf 83 (code=exited, status=0/SUCCESS)
   Main PID: 9184 (php-fpm8.3)
     Status: "Processes active: 0, idle: 2, Requests: 0, slow: 0, Traffic: 0.00req/sec"
      Tasks: 3 (limit: 1882)
     Memory: 7.7M (peak: 9.2M)
        CPU: 63ms
     CGroup: /system.slice/php8.3-fpm.service
             ├─9184 "php-fpm: master process (/etc/php/8.3/fpm/php-fpm.conf)"
             ├─9195 "php-fpm: pool www"
             └─9196 "php-fpm: pool www"

Mar 08 10:25:43 ub24base02 systemd[1]: Starting php8.3-fpm.service - The PHP 8.3 FastCGI Process Manager...
Mar 08 10:25:43 ub24base02 systemd[1]: Started php8.3-fpm.service - The PHP 8.3 FastCGI Process Manager.


● nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled; preset: enabled)
     Active: active (running) since Sun 2026-03-08 10:25:43 UTC; 21s ago
 Invocation: 51d0eaf55b8641279f9c9dfea71ea81f
       Docs: man:nginx(8)
    Process: 9186 ExecStartPre=/usr/sbin/nginx -t -q -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
    Process: 9188 ExecStart=/usr/sbin/nginx -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
   Main PID: 9190 (nginx)
      Tasks: 3 (limit: 1882)
     Memory: 2.8M (peak: 2.9M)
        CPU: 34ms
     CGroup: /system.slice/nginx.service
             ├─9190 "nginx: master process /usr/sbin/nginx -g daemon on; master_process on;"
             ├─9193 "nginx: worker process"
             └─9194 "nginx: worker process"

Mar 08 10:25:43 ub24base02 systemd[1]: Starting nginx.service - A high performance web server and a reverse proxy server...
Mar 08 10:25:43 ub24base02 systemd[1]: Started nginx.service - A high performance web server and a reverse proxy server.


● varnish.service - Varnish Cache, a high-performance HTTP accelerator
     Loaded: loaded (/usr/lib/systemd/system/varnish.service; enabled; preset: enabled)
     Active: active (running) since Sun 2026-03-08 10:25:43 UTC; 21s ago
```
