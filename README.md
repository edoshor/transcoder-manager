TranscoderManager
=================
[![Build Status](https://travis-ci.org/edoshor/transcoder-manager.png)](https://travis-ci.org/edoshor/transcoder-manager)
[![Coverage Status](https://coveralls.io/repos/edoshor/transcoder-manager/badge.png?branch=master)](https://coveralls.io/r/edoshor/transcoder-manager)


This is the backend REST api for managing BB web broadcast transcoders.


Installation
-

### Custom base path
By default, the application is expected to be served under the root path. If you want it to be served on a different path, use your favorite http server to reverse proxy it under whatever path you want. Just set a custom header, **X-Forwarded-Base-Path**, with this path.
