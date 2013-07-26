TranscoderManager
=================
[![Build Status](https://travis-ci.org/edoshor/transcoder-manager.png)](https://travis-ci.org/edoshor/transcoder-manager)
[![Coverage Status](https://coveralls.io/repos/edoshor/transcoder-manager/badge.png?branch=master)](https://coveralls.io/r/edoshor/transcoder-manager)


This is the backend REST api for managing BB web broadcast transcoders.


Installation
-

### Custom base path
By default, the application is expected to be served under the root path.
If you want it to be served on a different path.
Set a custom header, **X-Forwarded-Base-Path**, with this path (start with leading '/').

Example using Nginx:
```Nginx
location /custom/path/ {
  proxy_pass http://127.0.0.1:9292;
  proxy_set_header X-Forwarded-Base-Path /custom/path;
}

```
