local DIRECT_LOGIN_TARGET = "/users/sign_in?auto_sign_in=false"
local EXTERNAL_ROOT_URL = "https://git.${BASE_DOMAIN}"
local ADMIN_PATH = { exact = "/admin", prefix = "/admin/" }

local BLOCKED_RESPONSE_HTML = [[
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Access Blocked</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: #fafafa;
      padding: 60px;
      text-align: center;
      color: #333;
    }
    .card {
      display: inline-block;
      background: white;
      padding: 40px 50px;
      border-radius: 12px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.1);
    }
    h1 {
      color: #e24329;
      margin-bottom: 0.6em;
      font-size: 1.8em;
    }
  </style>
</head>
<body>
  <div class="card">
    <h1>403 – Admin Access Blocked</h1>
    <p>You do not have permission to access GitLab's admin interface.</p>
  </div>
</body>
</html>
]]

local function matches_path(path, blocked_path)
    return path == blocked_path.exact or string.sub(path, 1, #blocked_path.prefix) == blocked_path.prefix
end

function envoy_on_request(request_handle)
    local raw_path = request_handle:headers():get(":path") or ""

    if raw_path == DIRECT_LOGIN_TARGET then
        request_handle:respond({
            [":status"] = "302",
            ["location"] = EXTERNAL_ROOT_URL,
            ["content-type"] = "text/plain; charset=utf-8",
            ["cache-control"] = "no-store",
        }, "Direct login is blocked.")
        return
    end

    local path = string.match(raw_path, "^[^?]*") or raw_path
    if not matches_path(path, ADMIN_PATH) then
        return
    end

    request_handle:respond({
        [":status"] = "403",
        ["content-type"] = "text/html; charset=utf-8",
        ["cache-control"] = "no-store",
    }, BLOCKED_RESPONSE_HTML)
end
