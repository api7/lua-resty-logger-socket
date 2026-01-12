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

log_level('info');

run_tests();

__DATA__

=== TEST 1: UDP oversized log dropped, subsequent logs work
--- http_config eval
"$::HttpConfig"
--- config
    location = /t {
        content_by_lua_block {
            collectgarbage()

            package.loaded["resty.logger.socket"] = nil
            
            -- we try to create a new udp socket and override the send method
            local old_udp = ngx.socket.udp
            ngx.socket.udp = function()
                local sock, err = old_udp()
                if not sock then return nil, err end
                
                local proxy = {}
                local mt = {
                    __index = function(t, k)
                        return function(self, ...)
                            return sock[k](sock, ...)
                        end
                    end
                }
                setmetatable(proxy, mt)
                
                proxy.send = function(self, data)
                    if #data > 65000 then
                        return nil, "Message too long"
                    end
                    return sock:send(data)
                end
                
                return proxy
            end

            local logger_socket = require "resty.logger.socket"
            local logger, err = logger_socket:new({
                    host = "127.0.0.1",
                    port = 29999,
                    flush_limit = 100000,
                    sock_type = "udp",
                    max_retry_times = 0,
            })
            if not logger then
                ngx.say("failed to init logger: ", err)
                return
            end

            -- exceeed the max payload size of UDP
            local big_msg = string.rep("a", 70000)
            
            local bytes, err = logger:log(big_msg)
            ngx.say("log big bytes: ", bytes)
            
            -- this should fail
            local bytes, err = logger:flush(logger)
            ngx.say("flush big ret: ", bytes, " err: ", err)

            -- after flush send another message and then flushing should succeed
            local small_msg = "hello world"
            local bytes, err = logger:log(small_msg)
            ngx.say("log small bytes: ", bytes, " err: ", err)
            
            local bytes, err = logger:flush(logger)
            ngx.say("flush small ret: ", bytes, " err: ", err)
            
            ngx.say("done")
            
        }
    }
--- request
GET /t
--- wait: 0.1
--- udp_listen: 29999
--- udp_reply:
--- udp_query: hello world
--- response_body_like
log big bytes: \d+
flush big ret: nil err: nil
log small bytes: 11 err: try to send log messages to the log server failed after 0 retries: Message too long
flush small ret: \w+ err: nil
done
