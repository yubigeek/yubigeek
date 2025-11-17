vcl 4.1;

backend default {
    .host = "wordpress";
    .port = "80";
    .connect_timeout = 600s;
    .first_byte_timeout = 600s;
    .between_bytes_timeout = 600s;
}

acl purge {
    "localhost";
    "wordpress";
    "172.16.0.0"/12;
}

sub vcl_recv {
    # Remove has_js and CloudFlare/Google Analytics __* cookies
    set req.http.Cookie = regsuball(req.http.Cookie, "(^|;\s*)(_[_a-z]+|has_js)=[^;]*", "");
    # Remove a ";" prefix, if present.
    set req.http.Cookie = regsub(req.http.Cookie, "^;\s*", "");

    # Allow purging
    if (req.method == "PURGE") {
        if (!client.ip ~ purge) {
            return (synth(405, "Not allowed."));
        }
        return (purge);
    }

    # Allow BAN
    if (req.method == "BAN") {
        if (!client.ip ~ purge) {
            return (synth(405, "Not allowed."));
        }
        if (req.http.X-Purge-Method == "regex") {
            ban("obj.http.x-url ~ " + req.url + " && obj.http.x-host == " + req.http.host);
            return (synth(200, "Banned"));
        } else {
            ban("obj.http.x-url == " + req.url + " && obj.http.x-host == " + req.http.host);
            return (synth(200, "Banned"));
        }
    }

    # Only cache GET and HEAD requests
    if (req.method != "GET" && req.method != "HEAD") {
        return (pass);
    }

    # Don't cache HTTP authentication and HTTP Cookie
    if (req.http.Authorization || req.http.Cookie) {
        return (pass);
    }

    # Don't cache WordPress admin or login pages
    if (req.url ~ "wp-admin|wp-login|wp-cron|xmlrpc\.php") {
        return (pass);
    }

    # Don't cache WordPress preview pages
    if (req.url ~ "(\?|&)(preview=|preview_id=)") {
        return (pass);
    }

    # Don't cache cart/checkout/account pages for WooCommerce
    if (req.url ~ "/(cart|checkout|my-account|wc-api)") {
        return (pass);
    }

    # Remove cookies for static content
    if (req.url ~ "\.(css|js|jpg|jpeg|png|gif|ico|svg|webp|woff|woff2|ttf|eot)$") {
        unset req.http.Cookie;
    }

    return (hash);
}

sub vcl_backend_response {
    # Store URL and host for banning
    set beresp.http.x-url = bereq.url;
    set beresp.http.x-host = bereq.http.host;

    # Don't cache error responses
    if (beresp.status >= 500 && beresp.status <= 599) {
        set beresp.ttl = 0s;
        set beresp.uncacheable = true;
        return (deliver);
    }

    # Cache for 1 hour by default
    set beresp.ttl = 1h;
    set beresp.grace = 6h;

    # Remove Set-Cookie header for static content
    if (bereq.url ~ "\.(css|js|jpg|jpeg|png|gif|ico|svg|webp|woff|woff2|ttf|eot)$") {
        unset beresp.http.Set-Cookie;
        set beresp.ttl = 1w;
    }

    # Remove Set-Cookie if no cookies are set
    if (beresp.http.Set-Cookie !~ "wordpress_|comment_") {
        unset beresp.http.Set-Cookie;
    }

    return (deliver);
}

sub vcl_deliver {
    # Add cache hit/miss header
    if (obj.hits > 0) {
        set resp.http.X-Cache = "HIT";
        set resp.http.X-Cache-Hits = obj.hits;
    } else {
        set resp.http.X-Cache = "MISS";
    }

    # Remove internal headers
    unset resp.http.x-url;
    unset resp.http.x-host;
    unset resp.http.Via;
    unset resp.http.X-Varnish;

    return (deliver);
}
