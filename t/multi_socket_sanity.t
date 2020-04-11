# vim:set ft= ts=4 sw=4 et:

use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

repeat_each(2);

use Test::Nginx::Socket "no_plan";
our $HtmlDir = html_dir;

our $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;;";
    lua_package_cpath "/usr/local/openresty-debug/lualib/?.so;/usr/local/openresty/lualib/?.so;;";
};

$ENV{TEST_NGINX_RESOLVER} = '8.8.8.8';
$ENV{TEST_NGINX_HTML_DIR} = $HtmlDir;

no_long_string();

log_level('debug');

run_tests();

__DATA__
=== TEST 1: small flush_limit, instant flush, unix domain socket
--- http_config eval
"$::HttpConfig"
. q{
    server {
        listen 29999;
    }
}
--- config
    location = /t {
        content_by_lua_block {
            collectgarbage()  -- to help leak testing
            local logger_socket = require "resty.logger.socket"
            local logger = logger_socket:new()
            local ok, err = logger:init{
                host = "127.0.0.1",
                port = 29999,
                flush_limit = 1,
            }
            local ok, err = logger:log(ngx.var.request_uri)
            ngx.say("done")
            if not ok then
                ngx.say(err)
            end
        }
    }
--- request
GET /t
--- response_body
done
--- no_error_log
[error]

=== TEST 2: small flush_limit, instant flush, unix domain socket
--- http_config eval: $::HttpConfig
--- config
    location = /t {
           content_by_lua_block {
            collectgarbage()  -- to help leak testing
            local logger_socket = require "resty.logger.socket"
            local logger = logger_socket:new()
            local ok, err = logger:init{
                path = "$TEST_NGINX_HTML_DIR/logger_test.sock",
                flush_limit = 1,
            }
            local ok, err = logger:log(ngx.var.request_uri)
            ngx.say("done")
            if not ok then
                ngx.say(err)
            end
        }
    }
--- request
GET /t?a=1&b=2
--- wait: 0.1
--- tcp_listen eval: "$ENV{TEST_NGINX_HTML_DIR}/logger_test.sock"
--- tcp_reply:
--- response_body
done
--- no_error_log
[error]

=== TEST 3: small flush_limit, instant flush, write a number to remote
--- http_config eval
"$::HttpConfig"
. q{
    server {
        listen 29999;
    }
}
--- config
    location = /t {
        content_by_lua_block {
            collectgarbage()  -- to help leak testing
            local logger_socket = require "resty.logger.socket"
            local logger = logger_socket:new()
            local ok, err = logger:init{
                host = "127.0.0.1",
                port = 29999,
                flush_limit = 1,
            }
            local ok, err = logger:log(10)
            ngx.say("done")
            if not ok then
                ngx.say(err)
            end
        }
    }
--- request
GET /t
--- response_body
done
--- no_error_log
[error]

=== TEST 4: buffer log messages, no flush
--- http_config eval
"$::HttpConfig"
. q{
    server {
        listen 29999;
    }
}
--- config
    location = /t {
        content_by_lua_block {
            collectgarbage()  -- to help leak testing
            local logger_socket = require "resty.logger.socket"
            local logger = logger_socket:new()
            local ok, err = logger:init{
                host = "127.0.0.1",
                port = 29999,
                flush_limit = 500,
            }
            local ok, err = logger:log(10)
            ngx.say("done")
            if not ok then
                ngx.say(err)
            end
        }
    }
--- request
GET /t
--- response_body
done
--- no_error_log
[error]

=== TEST 5: not initted()
--- http_config eval
"$::HttpConfig"
. q{
    server {
        listen 29999;
    }
}
--- config
    location = /t {
        content_by_lua_block {
            local logger = require "resty.logger.socket"
            local bytes, err = logger.log(ngx.var.request_uri)
            if err then
                ngx.say(err)
            end
        }
    }
--- request
GET /t
--- response_body
not initialized
--- no_error_log
[error]

=== TEST 6: log subrequests
--- http_config eval
"$::HttpConfig"
. q{
    server {
        listen 29999;
    }
}
--- config
    log_subrequest on;
    location = /t {
         content_by_lua_block {
            collectgarbage()  -- to help leak testing
            local res = ngx.location.capture("/main?c=1&d=2")
            if res.status ~= 200 then
                ngx.log(ngx.ERR, "capture /main failed")
            end
            ngx.print(res.body)
        }
    }

    location = /main {
        content_by_lua_block {
            local logger_socket = require "resty.logger.socket"
            local logger = logger_socket:new()
            local ok, err = logger:init{
                host = "127.0.0.1",
                port = 29999,
                flush_limit = 6,
            }
            local ok, err = logger:log(10)
            ngx.say("done")
            if not ok then
                ngx.say(err)
            end
        }
    }

--- request
GET /t
--- response_body
done
--- no_error_log
[error]

=== TEST 7: bad user config
--- http_config eval
"$::HttpConfig"
. q{
    server {
        listen 29999;
    }
}
--- config
    location = /t {
        content_by_lua_block {
            local logger_socket = require "resty.logger.socket"
            local logger = logger_socket:new()
            local ok, err = logger.init("hello")
            if not ok then
                ngx.say(err)
            end

        }
    }
--- request
GET /t
--- response_body
user_config must be a table
--- no_error_log
[error]

=== TEST 8: bad user config: no host/port or path
--- http_config eval
"$::HttpConfig"
. q{
    server {
        listen 29999;
    }
}
--- config
    location = /t {
          content_by_lua_block {
            collectgarbage()  -- to help leak testing
            local logger_socket = require "resty.logger.socket"
            local logger = logger_socket:new()
            local ok, err = logger:init{
                flush_limit = 1,
                drop_limit = 2,
                retry_interval = 1,
                timeout = 100,
            }
            if not ok then
                ngx.say(err)
            end
        }
    }
--- request
GET /t
--- response_body
no logging server configured. "host"/"port" or "path" is required.
--- no_error_log
[error]

=== TEST 9: bad user config: flush_limit > drop_limit
--- http_config eval
"$::HttpConfig"
. q{
    server {
        listen 29999;
    }
}
--- config
    location = /t {
          content_by_lua_block {
            collectgarbage()  -- to help leak testing
            local logger_socket = require "resty.logger.socket"
            local logger = logger_socket:new()
            local ok, err = logger:init{
                flush_limit = 2,
                drop_limit = 1,
                path = "$TEST_NGINX_HTML_DIR/logger_test.sock",
            }
            if not ok then
                ngx.say(err)
            end
        }
    }
--- request
GET /t
--- response_body
"flush_limit" should be < "drop_limit"

