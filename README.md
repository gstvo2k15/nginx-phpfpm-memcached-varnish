# Introduction

This PoC validates a classic web application stack based on Varnish, Nginx, PHP-FPM and Memcached on Ubuntu 24.04.

Varnish acts as the HTTP reverse proxy cache, Nginx serves as the backend web server, PHP-FPM executes PHP code, and Memcached provides application-level caching.

The project demonstrates service chaining, request flow, backend troubleshooting, and the separation between HTTP caching and application object caching.

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

### Varnish log checks
```bash
varnishlog

*   << Request  >> 65556
-   Begin          req 65555 rxreq
-   Timestamp      Start: 1772966955.039686 0.000000 0.000000
-   Timestamp      Req: 1772966955.039686 0.000000 0.000000
-   VCL_use        boot
-   ReqStart       ::1 57770 a0
-   ReqMethod      HEAD
-   ReqURL         /
-   ReqProtocol    HTTP/1.1
-   ReqHeader      Host: localhost
-   ReqHeader      User-Agent: curl/8.9.1
-   ReqHeader      Accept: */*
-   ReqHeader      X-Forwarded-For: ::1
-   ReqHeader      Via: 1.1 ub24base02 (Varnish/7.5)
-   VCL_call       RECV
-   VCL_return     hash
-   VCL_call       HASH
-   VCL_return     lookup
-   Hit            21 -0.195382 10.000000 0.000000
-   VCL_call       HIT
-   VCL_return     deliver
-   Link           bereq 65557 bgfetch
-   Timestamp      Fetch: 1772966955.040109 0.000423 0.000423
-   RespProtocol   HTTP/1.1
-   RespStatus     200
-   RespReason     OK
-   RespHeader     Server: nginx/1.26.0 (Ubuntu)
-   RespHeader     Date: Sun, 08 Mar 2026 10:48:44 GMT
-   RespHeader     Content-Type: text/plain; charset=UTF-8
-   RespHeader     Cache-Control: public, max-age=30
-   RespHeader     X-App-Cache: HIT
-   RespHeader     X-Varnish: 65556 21
-   RespHeader     Age: 30
-   RespHeader     Via: 1.1 ub24base02 (Varnish/7.5)
-   RespHeader     Accept-Ranges: bytes
-   VCL_call       DELIVER
-   RespHeader     X-Cache: HIT
-   VCL_return     deliver
-   Timestamp      Process: 1772966955.040116 0.000429 0.000006
-   Filters
-   RespHeader     Content-Length: 134
-   RespHeader     Connection: keep-alive
-   Timestamp      Resp: 1772966955.040135 0.000449 0.000019
-   ReqAcct        73 0 73 327 0 327
-   End

*   << Session  >> 65555
-   Begin          sess 0 HTTP/1
-   SessOpen       ::1 57770 a0 ::1 80 1772966955.039657 20
-   Link           req 65556 rxreq
-   SessClose      REM_CLOSE 0.001
-   End

*   << BeReq    >> 65557
-   Begin          bereq 65556 bgfetch
-   VCL_use        boot
-   Timestamp      Start: 1772966955.040096 0.000000 0.000000
-   BereqMethod    HEAD
-   BereqURL       /
-   BereqProtocol  HTTP/1.1
-   BereqHeader    Host: localhost
-   BereqHeader    User-Agent: curl/8.9.1
-   BereqHeader    Accept: */*
-   BereqHeader    X-Forwarded-For: ::1
-   BereqHeader    Via: 1.1 ub24base02 (Varnish/7.5)
-   BereqMethod    GET
-   BereqHeader    Accept-Encoding: gzip
-   BereqHeader    X-Varnish: 65557
-   VCL_call       BACKEND_FETCH
-   VCL_return     fetch
-   Timestamp      Fetch: 1772966955.040146 0.000050 0.000050
-   Timestamp      Connected: 1772966955.040148 0.000052 0.000001
-   BackendOpen    23 default 127.0.0.1 8080 127.0.0.1 45538 reuse
-   Timestamp      Bereq: 1772966955.040272 0.000175 0.000123
-   BerespProtocol HTTP/1.1
-   BerespStatus   200
-   BerespReason   OK
-   BerespHeader   Server: nginx/1.26.0 (Ubuntu)
-   BerespHeader   Date: Sun, 08 Mar 2026 10:49:15 GMT
-   BerespHeader   Content-Type: text/plain; charset=UTF-8
-   BerespHeader   Transfer-Encoding: chunked
-   BerespHeader   Connection: keep-alive
-   BerespHeader   Cache-Control: public, max-age=30
-   BerespHeader   X-App-Cache: MISS
-   Timestamp      Beresp: 1772966955.041289 0.001192 0.001017
-   TTL            RFC 30 10 0 1772966955 1772966955 1772966955 0 30 cacheable
-   VCL_call       BACKEND_RESPONSE
-   TTL            VCL 30 10 0 1772966955 cacheable
-   VCL_return     deliver
-   Timestamp      Process: 1772966955.041328 0.001231 0.000039
-   Filters
-   Storage        malloc s0
-   Fetch_Body     2 chunked stream
-   BackendClose   23 default recycle
-   Timestamp      BerespBody: 1772966955.041391 0.001295 0.000063
-   Length         135
-   BereqAcct      170 0 170 234 135 369
-   End

*   << Request  >> 32783
-   Begin          req 32782 rxreq
-   Timestamp      Start: 1772966957.049903 0.000000 0.000000
-   Timestamp      Req: 1772966957.049903 0.000000 0.000000
-   VCL_use        boot
-   ReqStart       ::1 57786 a0
-   ReqMethod      HEAD
-   ReqURL         /
-   ReqProtocol    HTTP/1.1
-   ReqHeader      Host: localhost
-   ReqHeader      User-Agent: curl/8.9.1
-   ReqHeader      Accept: */*
-   ReqHeader      X-Forwarded-For: ::1
-   ReqHeader      Via: 1.1 ub24base02 (Varnish/7.5)
-   VCL_call       RECV
-   VCL_return     hash
-   VCL_call       HASH
-   VCL_return     lookup
-   Hit            65557 27.991386 10.000000 0.000000
-   VCL_call       HIT
-   VCL_return     deliver
-   RespProtocol   HTTP/1.1
-   RespStatus     200
-   RespReason     OK
-   RespHeader     Server: nginx/1.26.0 (Ubuntu)
-   RespHeader     Date: Sun, 08 Mar 2026 10:49:15 GMT
-   RespHeader     Content-Type: text/plain; charset=UTF-8
-   RespHeader     Cache-Control: public, max-age=30
-   RespHeader     X-App-Cache: MISS
-   RespHeader     X-Varnish: 32783 65557
-   RespHeader     Age: 2
-   RespHeader     Via: 1.1 ub24base02 (Varnish/7.5)
-   RespHeader     Accept-Ranges: bytes
-   VCL_call       DELIVER
-   RespHeader     X-Cache: HIT
-   VCL_return     deliver
-   Timestamp      Process: 1772966957.049932 0.000029 0.000029
-   Filters
-   RespHeader     Content-Length: 135
-   RespHeader     Connection: keep-alive
-   Timestamp      Resp: 1772966957.049955 0.000052 0.000023
-   ReqAcct        73 0 73 330 0 330
-   End

*   << Session  >> 32782
-   Begin          sess 0 HTTP/1
-   SessOpen       ::1 57786 a0 ::1 80 1772966957.049887 22
-   Link           req 32783 rxreq
-   SessClose      REM_CLOSE 0.001
-   End

*   << Request  >> 98306
-   Begin          req 98305 rxreq
-   Timestamp      Start: 1772966959.059798 0.000000 0.000000
-   Timestamp      Req: 1772966959.059798 0.000000 0.000000
-   VCL_use        boot
-   ReqStart       ::1 46738 a0
-   ReqMethod      HEAD
-   ReqURL         /
-   ReqProtocol    HTTP/1.1
-   ReqHeader      Host: localhost
-   ReqHeader      User-Agent: curl/8.9.1
-   ReqHeader      Accept: */*
-   ReqHeader      X-Forwarded-For: ::1
-   ReqHeader      Via: 1.1 ub24base02 (Varnish/7.5)
-   VCL_call       RECV
-   VCL_return     hash
-   VCL_call       HASH
-   VCL_return     lookup
-   Hit            65557 25.981491 10.000000 0.000000
-   VCL_call       HIT
-   VCL_return     deliver
-   RespProtocol   HTTP/1.1
-   RespStatus     200
-   RespReason     OK
-   RespHeader     Server: nginx/1.26.0 (Ubuntu)
-   RespHeader     Date: Sun, 08 Mar 2026 10:49:15 GMT
-   RespHeader     Content-Type: text/plain; charset=UTF-8
-   RespHeader     Cache-Control: public, max-age=30
-   RespHeader     X-App-Cache: MISS
-   RespHeader     X-Varnish: 98306 65557
-   RespHeader     Age: 4
-   RespHeader     Via: 1.1 ub24base02 (Varnish/7.5)
-   RespHeader     Accept-Ranges: bytes
-   VCL_call       DELIVER
-   RespHeader     X-Cache: HIT
-   VCL_return     deliver
-   Timestamp      Process: 1772966959.059842 0.000043 0.000043
-   Filters
-   RespHeader     Content-Length: 135
-   RespHeader     Connection: keep-alive
-   Timestamp      Resp: 1772966959.059893 0.000094 0.000050
-   ReqAcct        73 0 73 330 0 330
-   End

*   << Session  >> 98305
-   Begin          sess 0 HTTP/1
-   SessOpen       ::1 46738 a0 ::1 80 1772966959.059770 21
-   Link           req 98306 rxreq
-   SessClose      REM_CLOSE 0.001
-   End

*   << Request  >> 32785
-   Begin          req 32784 rxreq
-   Timestamp      Start: 1772966961.068117 0.000000 0.000000
-   Timestamp      Req: 1772966961.068117 0.000000 0.000000
-   VCL_use        boot
-   ReqStart       ::1 46752 a0
-   ReqMethod      HEAD
-   ReqURL         /
-   ReqProtocol    HTTP/1.1
-   ReqHeader      Host: localhost
-   ReqHeader      User-Agent: curl/8.9.1
-   ReqHeader      Accept: */*
-   ReqHeader      X-Forwarded-For: ::1
-   ReqHeader      Via: 1.1 ub24base02 (Varnish/7.5)
-   VCL_call       RECV
-   VCL_return     hash
-   VCL_call       HASH
-   VCL_return     lookup
-   Hit            65557 23.973171 10.000000 0.000000
-   VCL_call       HIT
-   VCL_return     deliver
-   RespProtocol   HTTP/1.1
-   RespStatus     200
-   RespReason     OK
-   RespHeader     Server: nginx/1.26.0 (Ubuntu)
-   RespHeader     Date: Sun, 08 Mar 2026 10:49:15 GMT
-   RespHeader     Content-Type: text/plain; charset=UTF-8
-   RespHeader     Cache-Control: public, max-age=30
-   RespHeader     X-App-Cache: MISS
-   RespHeader     X-Varnish: 32785 65557
-   RespHeader     Age: 6
-   RespHeader     Via: 1.1 ub24base02 (Varnish/7.5)
-   RespHeader     Accept-Ranges: bytes
-   VCL_call       DELIVER
-   RespHeader     X-Cache: HIT
-   VCL_return     deliver
-   Timestamp      Process: 1772966961.068145 0.000027 0.000027
-   Filters
-   RespHeader     Content-Length: 135
-   RespHeader     Connection: keep-alive
-   Timestamp      Resp: 1772966961.068190 0.000072 0.000045
-   ReqAcct        73 0 73 330 0 330
-   End

*   << Session  >> 32784
-   Begin          sess 0 HTTP/1
-   SessOpen       ::1 46752 a0 ::1 80 1772966961.068105 20
-   Link           req 32785 rxreq
-   SessClose      REM_CLOSE 0.000
-   End
```

### Memcached log checks
```bash
apt install -y netcat-openbsd
netcat-openbsd is already the newest version (1.226-1.1).
netcat-openbsd set to manually installed.
Summary:
  Upgrading: 0, Installing: 0, Removing: 0, Not Upgrading: 0
root@ub24base02:~#
root@ub24base02:~#
root@ub24base02:~# printf "stats\nquit\n" | nc 127.0.0.1 11211
STAT pid 10828
STAT uptime 315
STAT time 1772967047
STAT version 1.6.29
STAT libevent 2.1.12-stable
STAT pointer_size 64
STAT rusage_user 0.058244
STAT rusage_system 0.010278
STAT max_connections 1024
STAT curr_connections 2
STAT total_connections 17
STAT rejected_connections 0
STAT connection_structures 3
STAT response_obj_oom 0
STAT response_obj_count 1
STAT response_obj_bytes 65536
STAT read_buf_count 8
STAT read_buf_bytes 131072
STAT read_buf_bytes_free 49152
STAT read_buf_oom 0
STAT reserved_fds 20
STAT cmd_get 14
STAT cmd_set 5
STAT cmd_flush 0
STAT cmd_touch 0
STAT cmd_meta 0
STAT get_hits 9
STAT get_misses 5
STAT get_expired 1
STAT get_flushed 0
STAT delete_misses 0
STAT delete_hits 0
STAT incr_misses 0
STAT incr_hits 0
STAT decr_misses 0
STAT decr_hits 0
STAT cas_misses 0
STAT cas_hits 0
STAT cas_badval 0
STAT touch_hits 0
STAT touch_misses 0
STAT store_too_large 0
STAT store_no_memory 0
STAT auth_cmds 0
STAT auth_errors 0
STAT bytes_read 1184
STAT bytes_written 1532
STAT limit_maxbytes 268435456
STAT accepting_conns 1
STAT listen_disabled_num 0
STAT time_in_listen_disabled_us 0
STAT threads 4
STAT conn_yields 0
STAT hash_power_level 16
STAT hash_bytes 524288
STAT hash_is_expanding 0
STAT slab_reassign_rescues 0
STAT slab_reassign_chunk_rescues 0
STAT slab_reassign_evictions_nomem 0
STAT slab_reassign_inline_reclaim 0
STAT slab_reassign_busy_items 0
STAT slab_reassign_busy_deletes 0
STAT slab_reassign_running 0
STAT slabs_moved 0
STAT lru_crawler_running 0
STAT lru_crawler_starts 3
STAT lru_maintainer_juggles 652
STAT malloc_fails 0
STAT log_worker_dropped 0
STAT log_worker_written 0
STAT log_watcher_skipped 0
STAT log_watcher_sent 0
STAT log_watchers 0
STAT unexpected_napi_ids 0
STAT round_robin_fallback 0
STAT bytes 205
STAT curr_items 1
STAT total_items 5
STAT slab_global_page_pool 0
STAT expired_unfetched 0
STAT evicted_unfetched 0
STAT evicted_active 0
STAT evictions 0
STAT reclaimed 3
STAT crawler_reclaimed 0
STAT crawler_items_checked 1
STAT lrutail_reflocked 4
STAT moves_to_cold 9
STAT moves_to_warm 4
STAT moves_within_lru 0
STAT direct_reclaims 0
STAT lru_bumps_dropped 0
END
```