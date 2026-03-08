#!/bin/bash

cat >/var/www/html/index.php <<'EOF'
<?php

$memcached = new Memcached();
$memcached->addServer('127.0.0.1', 11211);

$key = 'demo_page_cache';
$data = $memcached->get($key);

$app_cache = 'MISS';

if ($data === false) {
    $data = [
        'generated_at' => date('c'),
        'hostname' => gethostname(),
        'random_value' => bin2hex(random_bytes(4)),
    ];
    $memcached->set($key, $data, 60);
} else {
    $app_cache = 'HIT';
}

header('Content-Type: text/plain; charset=UTF-8');
header('Cache-Control: public, max-age=30');
header('X-App-Cache: ' . $app_cache);

echo "PHP-FPM + Memcached + Varnish demo\n";
echo "Hostname: " . $data['hostname'] . "\n";
echo "Generated at: " . $data['generated_at'] . "\n";
echo "Random value: " . $data['random_value'] . "\n";
echo "App cache: " . $app_cache . "\n";
EOF

systemctl restart php8.3-fpm
systemctl restart nginx
systemctl restart varnish

echo -e "\nTesting the newest curl: "
curl -Ik http://127.0.0.1:8080/

curl -Ik http://127.0.0.1/
curl -Ik http://127.0.0.1/


cat >/etc/varnish/default.vcl <<'EOF'
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
EOF


systemctl restart varnish

curl -i http://127.0.0.1:80
curl -i http://127.0.0.1:80
curl -i http://127.0.0.1:80
