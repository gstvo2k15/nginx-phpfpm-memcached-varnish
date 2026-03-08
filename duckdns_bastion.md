## DIAGRAM
```bash
                     Internet
                         │
                         │  HTTPS (TLS)
                         │
                nginxgolmolab.duckdns.org
                         │
                         ▼
                Nginx Frontend :8443
                - TLS termination
                - Security headers
                - HTTP → HTTPS redirect (80)
                         │
                         │ proxy_pass
                         ▼
                  Varnish :6081
                - HTTP cache
                - X-Cache HIT/MISS
                - TTL control
                         │
                         │ backend
                         ▼
               Nginx Backend :8080
                - Web server
                - FastCGI handler
                         │
                         │ fastcgi_pass
                         ▼
                   PHP-FPM
                - PHP runtime
                - worker pool
                         │
                         │ application cache
                         ▼
                   Memcached
                - object cache
                - session/data cache
                                     Internet
                         │
                         │  HTTPS (TLS)
                         │
                nginxgolmolab.duckdns.org
                         │
                         ▼
                Nginx Frontend :8443
                - TLS termination
                - Security headers
                - HTTP → HTTPS redirect (80)
                         │
                         │ proxy_pass
                         ▼
                  Varnish :6081
                - HTTP cache
                - X-Cache HIT/MISS
                - TTL control
                         │
                         │ backend
                         ▼
               Nginx Backend :8080
                - Web server
                - FastCGI handler
                         │
                         │ fastcgi_pass
                         ▼
                   PHP-FPM
                - PHP runtime
                - worker pool
                         │
                         │ application cache
                         ▼
                   Memcached
                - object cache
                - session/data cache
```


## VARNISH & MEMCACHED

**cat /etc/varnish/default.vcl**
```bash
vcl 4.1;

backend default {
    .host = "127.0.0.1";
    .port = "8080";
}

sub vcl_recv {
    if (req.method != "GET" && req.method != "HEAD") {
        return (pass);
    }
}

sub vcl_backend_response {
    if (beresp.http.Cache-Control ~ "max-age") {
        set beresp.ttl = 30s;
    }
}

sub vcl_deliver {
    if (obj.hits > 0) {
        set resp.http.X-Cache = "HIT";
    } else {
        set resp.http.X-Cache = "MISS";
    }
}
```

**cat /usr/lib/systemd/system/varnish.service**
```bash
[Unit]
Description=Varnish Cache, a high-performance HTTP accelerator
Documentation=https://www.varnish-cache.org/docs/ man:varnishd

[Service]
Type=exec
LimitNOFILE=131072
LimitMEMLOCK=85983232
ExecStart=/usr/sbin/varnishd \
          -F \
          -a :6081 \
          -T localhost:6082 \
          -f /etc/varnish/default.vcl \
          -S /etc/varnish/secret \
          -s malloc,256m
ExecReload=/usr/share/varnish/varnishreload
Restart=on-failure
KillMode=mixed
ConfigurationDirectory=varnish
ProtectSystem=full
ProtectHome=true
PrivateTmp=true
PrivateDevices=true

[Install]
WantedBy=multi-user.target
```

**cat /etc/memcached.conf**
```bash
-d
logfile /var/log/memcached.log

-m 256
-p 11211
-u memcache
-l 127.0.0.1
```

## NGINX

`https://securityheaders.com/?q=https%3A%2F%2Fnginxgolmolab.duckdns.org%3A8443%2F&followRedirects=on`

**cat etc/nginx/snippets/security-headers.conf**
```bash
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
add_header Content-Security-Policy "default-src 'self'; base-uri 'self'; frame-ancestors 'self'; object-src 'none';" always;
```

**cat /etc/nginx/snippets/hsts.conf**
```bash
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
```

**cat /etc/nginx/sites-available/nginxgolmolab.duckdns.org**
```bash
server {
    listen 8443 ssl;
    server_name nginxgolmolab.duckdns.org;

    ssl_certificate /etc/letsencrypt/live/nginxgolmolab.duckdns.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/nginxgolmolab.duckdns.org/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    include /etc/nginx/snippets/security-headers.conf;
    include /etc/nginx/snippets/hsts.conf;

    location / {
        proxy_pass http://127.0.0.1:6081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;

        proxy_hide_header Strict-Transport-Security;
        proxy_hide_header X-Frame-Options;
        proxy_hide_header X-Content-Type-Options;
        proxy_hide_header Referrer-Policy;
        proxy_hide_header Permissions-Policy;
        proxy_hide_header Content-Security-Policy;
    }
}
```

```bash
Security Report Summary
A+
Site:	https://nginxgolmolab.duckdns.org:8443/
IP Address:	XX.XXX.xx.XXX
Report Time:	08 Mar 2026 12:16:25 UTC
Headers:
X-Frame-Options X-Content-Type-Options Referrer-Policy Permissions-Policy Content-Security-Policy Strict-Transport-Security
Advanced:	
Wow, amazing grade! Perform a deeper security analysis of your website and APIs:	
Warnings
Response is not HTML	The content-type of the response does not indicate HTML. Not all headers, and therefore the score, may be appropriate.
```
