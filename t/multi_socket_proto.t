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

=== TEST 1: default sock_type (tcp)
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
GET /t?a=1&b=2
--- wait: 0.1
--- tcp_reply:
--- no_error_log
[error]
--- tcp_query: /t?a=1&b=2
--- tcp_query_len: 10



=== TEST 2: set sock_type tcp
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
                    sock_type = "tcp",
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
GET /t?a=1&b=2
--- wait: 0.1
--- tcp_reply:
--- no_error_log
[error]
--- tcp_query: /t?a=1&b=2
--- tcp_query_len: 10



=== TEST 3: set sock_type udp
--- http_config eval: $::HttpConfig
--- config
    location = /t {
         content_by_lua_block {
            collectgarbage()  -- to help leak testing
             local logger_socket = require "resty.logger.socket"
            local logger, err = logger_socket:new({
                    host = "127.0.0.1",
                    port = 29999,
                    sock_type = "udp",
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
GET /t?a=1&b=2
--- wait: 0.1
--- udp_listen: 29999
--- udp_reply:
--- no_error_log
[error]
--- udp_query: /t?a=1&b=2
