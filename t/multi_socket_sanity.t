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
            local logger, err = logger_socket:new({
                host = "127.0.0.1",
                port = 29999,
                flush_limit = 1,
            })

            if not logger then
                ngx.log(ngx.ERR, "failed to create logger: ", err)
            end

            local ok, err = logger:log(ngx.var.request_uri)
            ngx.say("done")

            if not ok then
                ngx.log(ngx.ERR, err)
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
            local logger, err = logger_socket:new({
                path = "$TEST_NGINX_HTML_DIR/logger_test.sock",
                flush_limit = 1,
            })

            if not logger then
                ngx.log(ngx.ERR, "failed to create logger: ", err)
            end
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
            local logger, err = logger_socket:new({
                host = "127.0.0.1",
                port = 29999,
                flush_limit = 1,
            })

            if not logger then
                ngx.log(ngx.ERR, "failed to create logger: ", err)
            end
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
            local logger, err = logger_socket:new({
                host = "127.0.0.1",
                port = 29999,
                flush_limit = 500,
            })

            if not logger then
                ngx.log(ngx.ERR, "failed to create logger: ", err)
            end
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
            local logger, err = logger_socket:new({
                host = "127.0.0.1",
                port = 29999,
                flush_limit = 6,
            })

            if not logger then
                ngx.log(ngx.ERR, "failed to create logger: ", err)
            end

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
            local logger, err = logger_socket:new({
                flush_limit = 1,
                drop_limit = 2,
                retry_interval = 1,
                timeout = 100,
            })

            if not logger then
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
            local logger, err = logger_socket:new({
                flush_limit = 2,
                drop_limit = 1,
                path = "$TEST_NGINX_HTML_DIR/logger_test.sock",
            })
            if not ok then
                ngx.say(err)
            end
        }
    }
--- request
GET /t
--- response_body
"flush_limit" should be < "drop_limit"



=== TEST 10: logger response
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
            ngx.say("foo")
            local logger_socket = require "resty.logger.socket"
            local logger, err = logger_socket:new({
                host = "127.0.0.1",
                port = 29999,
                flush_limit = 1,
            })

            local bytes, err = logger:log(ngx.var.request_uri)
            if err then
                ngx.log(ngx.ERR, err)
            end
            ngx.say("wrote bytes: ", bytes)
        }
    }
--- request
GET /t?a=1&b=2
--- wait: 0.1
--- tcp_reply:
--- no_error_log
[error]
--- no_error_log
--- response_body
foo
wrote bytes: 10



=== TEST 11: logger response
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
            ngx.say("foo")
            local logger_socket = require "resty.logger.socket"
            local logger, err = logger_socket:new({
                    host = "127.0.0.1",
                    port = 29999,
                    flush_limit = 10,
                    drop_limit = 11,
            })

            local bytes, err = logger:log(ngx.var.request_uri)
            if err then
                ngx.log(ngx.ERR, err)
            end
            -- byte1 should be 0
            local bytes1, err1 = logger:log(ngx.var.request_uri)
            if err1 then
                ngx.log(ngx.ERR, err1)
            end
            ngx.say("wrote bytes: ", bytes + bytes1)
        }
    }
--- request
GET /t?a=1&b=2
--- wait: 0.1
--- tcp_reply:
--- no_error_log
[error]
--- tcp_query: /t?a=1&b=2
--- tcp_query_len: 10
--- response_body
foo
wrote bytes: 10



=== TEST 12: flush periodically
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
            ngx.say("foo")
            local logger_socket = require "resty.logger.socket"
            local logger, err = logger_socket:new({
                    host = "127.0.0.1",
                    port = 29999,
                    flush_limit = 1000,
                    drop_limit = 10000,
                    periodic_flush = 0.03, -- 0.03s
             })

            local bytes, err
            bytes, err = logger:log("foo")
            if err then
                ngx.log(ngx.ERR, err)
            end
            ngx.say("wrote bytes: ", bytes)

            ngx.sleep(0.05)

            bytes, err = logger:log("bar")
            if err then
                ngx.log(ngx.ERR, err)
            end
            ngx.say("wrote bytes: ", bytes)
            ngx.sleep(0.05)
        }
    }
--- request
GET /t
--- wait: 0.1
--- tcp_reply:
--- tcp_query: foobar
--- tcp_query_len: 6
--- response_body
foo
wrote bytes: 3
wrote bytes: 3



=== TEST 13: SSL logging
--- http_config eval
"
    lua_package_path '$::pwd/lib/?.lua;;';
    server {
        listen unix:$::HtmlDir/ssl.sock ssl;
        server_name test.com;
        ssl_certificate $::pwd/t/cert/test.crt;
        ssl_certificate_key $::pwd/t/cert/test.key;

        location /test {
            lua_need_request_body on;
            default_type 'text/plain';
            # 204 No content
            content_by_lua '
                ngx.log(ngx.WARN, \"Message received: \", ngx.var.http_message)
                ngx.log(ngx.WARN, \"SNI Host: \", ngx.var.ssl_server_name)
                ngx.exit(204)
            ';
        }
    }
"
--- config
    location = /t {
        content_by_lua '
            ngx.say("foo")
            local logger_socket = require "resty.logger.socket"
            local logger, err = logger_socket:new({
                    path = "$TEST_NGINX_HTML_DIR/ssl.sock",
                    flush_limit = 1,
                    ssl = true,
                    ssl_verify = false,
                    sni_host = "test.com",
            })

            local bytes, err
            bytes, err = logger:log("GET /test HTTP/1.0\\r\\nHost: test.com\\r\\nConnection: close\\r\\nMessage: Hello SSL\\r\\n\\r\\n")
            if err then
                ngx.log(ngx.ERR, err)
            end
            ngx.say("wrote bytes: ", bytes)

            ngx.sleep(0.05)
        ';
    }
--- request
GET /t
--- wait: 0.1
--- response_body
foo
wrote bytes: 77
--- error_log
Message received: Hello SSL
SNI Host: test.com



=== TEST 14: SSL logging - Verify
--- http_config eval
"
    lua_package_path '$::pwd/lib/?.lua;;';
    server {
        listen unix:$::HtmlDir/ssl.sock ssl;
        server_name test.com;
        ssl_certificate $::pwd/t/cert/test.crt;
        ssl_certificate_key $::pwd/t/cert/test.key;

        location /test {
            lua_need_request_body on;
            default_type 'text/plain';
            # 204 No content
            content_by_lua 'ngx.log(ngx.WARN, \"Message received: \", ngx.var.http_message) ngx.exit(204)';
        }
    }
"
--- config
    location = /t {
        content_by_lua '
            ngx.say("foo")
            local logger_socket = require "resty.logger.socket"
            local logger, err = logger_socket:new({
                path = "$TEST_NGINX_HTML_DIR/ssl.sock",
                flush_limit = 1,
                ssl = true,
                ssl_verify = true,
                sni_host = "test.com",
            })

            local bytes, err
            bytes, err = logger:log("GET /test HTTP/1.0\\r\\nHost: test.com\\r\\nConnection: close\\r\\nMessage: Hello SSL\\r\\n\\r\\n")
            if err then
                ngx.log(ngx.ERR, err)
            end
            ngx.say("wrote bytes: ", bytes)

            ngx.sleep(0.05)
        ';
    }
--- request
GET /t
--- wait: 0.1
--- response_body
foo
wrote bytes: 77
--- error_log
lua ssl certificate verify error



=== TEST 15: SSL logging - No SNI
--- http_config eval
"
    lua_package_path '$::pwd/lib/?.lua;;';
    server {
        listen unix:$::HtmlDir/ssl.sock ssl;
        server_name test.com;
        ssl_certificate $::pwd/t/cert/test.crt;
        ssl_certificate_key $::pwd/t/cert/test.key;

        location /test {
            lua_need_request_body on;
            default_type 'text/plain';
            # 204 No content
            content_by_lua '
                ngx.log(ngx.WARN, \"Message received: \", ngx.var.http_message)
                ngx.log(ngx.WARN, \"SNI Host: \", ngx.var.ssl_server_name)
                ngx.exit(204)
            ';
        }
    }
"
--- config
    location = /t {
        content_by_lua '
            ngx.say("foo")
            local logger_socket = require "resty.logger.socket"
            local logger, err = logger_socket:new({
                path = "$TEST_NGINX_HTML_DIR/ssl.sock",
                flush_limit = 1,
                ssl = true,
                ssl_verify = false,
            })

            local bytes, err
            bytes, err = logger:log("GET /test HTTP/1.0\\r\\nHost: test.com\\r\\nConnection: close\\r\\nMessage: Hello SSL\\r\\n\\r\\n")
            if err then
                ngx.log(ngx.ERR, err)
            end
            ngx.say("wrote bytes: ", bytes)

            ngx.sleep(0.05)
        ';
    }
--- request
GET /t
--- wait: 0.1
--- response_body
foo
wrote bytes: 77
--- error_log
Message received: Hello SSL
SNI Host: nil



=== TEST 16: Test arguments
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua 'ngx.say("foo")';
        log_by_lua '
            local logger_socket = require "resty.logger.socket"
            local ok, err = logger_socket:new({ host = 128, port = 29999 })
            ngx.log(ngx.ERR, err)

            local ok, err = logger_socket:new({ host = "google.com", port = "foo" })
            ngx.log(ngx.ERR, err)

            local ok, err = logger_socket:new({ host = "google.com", port = 1234567 })
            ngx.log(ngx.ERR, err)

            local ok, err = logger_socket:new({ sock_type = true })
            ngx.log(ngx.ERR, err)

            local ok, err = logger_socket:new({ sock_type = "upd" })
            ngx.log(ngx.ERR, err)

            local ok, err = logger_socket:new({ path = 123 })
            ngx.log(ngx.ERR, err)

            local ok, err = logger_socket:new({ path = "/test.sock", flush_limit = "a" })
            ngx.log(ngx.ERR, err)

            local ok, err = logger_socket:new({ path = "/test.sock", drop_limit = -2.5 })
            ngx.log(ngx.ERR, err)

            local ok, err = logger_socket:new({ path = "/test.sock", timeout = "bar" })
            ngx.log(ngx.ERR, err)

            local ok, err = logger_socket:new({ path = "/test.sock", max_retry_times = "bar" })
            ngx.log(ngx.ERR, err)

            local ok, err = logger_socket:new({ path = "/test.sock", retry_interval = "bar" })
            ngx.log(ngx.ERR, err)

            local ok, err = logger_socket:new({ path = "/test.sock", pool_size = "bar" })
            ngx.log(ngx.ERR, err)

            local ok, err = logger_socket:new({ path = "/test.sock", max_buffer_reuse = "bar" })
            ngx.log(ngx.ERR, err)

            local ok, err = logger_socket:new({ path = "/test.sock", periodic_flush = "bar" })
            ngx.log(ngx.ERR, err)

            local ok, err = logger_socket:new({ path = "/test.sock", ssl = "1" })
            ngx.log(ngx.ERR, err)

            local ok, err = logger_socket:new({ path = "/test.sock", ssl_verify = 2 })
            ngx.log(ngx.ERR, err)

            local ok, err = logger_socket:new({ path = "/test.sock", sni_host = true })
            ngx.log(ngx.ERR, err)
        ';
    }
--- request
GET /t?a=1&b=2
--- error_log
"host" must be a string
"port" must be a number
"port" out of range 0~65535
"sock_type" must be a string
"sock_type" must be "tcp" or "udp"
"path" must be a string
invalid "flush_limit"
invalid "drop_limit"
invalid "timeout"
invalid "max_retry_times"
invalid "retry_interval"
invalid "pool_size"
invalid "max_buffer_reuse"
invalid "periodic_flush"
"ssl" must be a boolean value
"ssl_verify" must be a boolean value
"sni_host" must be a string
--- response_body
foo
