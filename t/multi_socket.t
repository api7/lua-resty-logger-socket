# vim:set ft= ts=4 sw=4 et:

use Test::Nginx::Socket::Lua "no_plan";
use Cwd qw(cwd);

repeat_each(1);

my $pwd = cwd();
our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;;";
};

no_long_string();
log_level('info');

run_tests();

__DATA__

=== TEST 1: create 2 logger_socket oblects
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua 'ngx.say("foo")';
        log_by_lua '
            collectgarbage()  -- to help leak testing

            local logger_socket = require "resty.logger.socket"
            local logger = logger_socket:new()
            if not logger:initted() then
                local ok, err = logger:init{
                    host = "127.0.0.1",
                    port = 29999,
                    flush_limit = 1,
                }

                local bytes, err = logger:log(ngx.var.request_uri)
                if err then
                    ngx.log(ngx.ERR, err)
                end
            end
        ';
    }
--- request eval
["GET /t?a=1&b=2", "GET /t?c=3&d=4"]
--- wait: 0.1
--- tcp_listen: 29999
--- tcp_reply:
--- no_error_log
[error]
--- tcp_query eval: "/t?a=1&b=2/t?c=3&d=4"
--- tcp_query_len: 20
--- response_body eval
["foo\n", "foo\n"]



=== TEST 2: new2 (new + init)
--- http_config eval: $::HttpConfig
--- config
location /t {
    content_by_lua_block {
        ngx.print("foo")
    }

    log_by_lua_block {
        collectgarbage()  -- to help leak testing

        local logger_socket = require("resty.logger.socket")
        local logger, err = logger_socket:new({
            host = "127.0.0.1",
            port = 29999,
            flush_limit = 1,
        })

        if not logger then
            ngx.log(ngx.ERR, "failed to create logger: ", err)
        end

        local bytes, err = logger:log(ngx.var.request_uri)
        if err then
            ngx.log(ngx.ERR, err)
        end
    }
}
--- request eval
["GET /t?a=1&b=2", "GET /t?c=3&d=4"]
--- wait: 0.1
--- tcp_listen: 29999
--- tcp_reply:
--- no_error_log
[error]
--- tcp_query eval: "/t?a=1&b=2/t?c=3&d=4"
--- tcp_query_len: 20
--- response_body eval
["foo", "foo"]
