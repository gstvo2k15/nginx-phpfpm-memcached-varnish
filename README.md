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
