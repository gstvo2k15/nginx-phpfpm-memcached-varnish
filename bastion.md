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