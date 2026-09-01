local ADMIN_PATH = { exact = "/config", prefix = "/config/" }

local BLOCKED_RESPONSE_HTML = [[
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Access Blocked</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      background: #fafafa;
      padding: 50px;
      text-align: center;
      color: #333;
    }
    .card {
      display: inline-block;
      background: white;
      padding: 30px 40px;
      border-radius: 12px;
      box-shadow: 0 4px 10px rgba(0,0,0,0.1);
    }
    h1 {
      color: #c00;
    }
  </style>
</head>
<body>
  <div class="card">
    <h1>403 – Admin Access Blocked</h1>
    <p>You are not allowed to access the SABnzbd configuration area.</p>
  </div>
</body>
</html>
]]

local function matches_path(path, blocked_path)
    return path == blocked_path.exact or string.sub(path, 1, #blocked_path.prefix) == blocked_path.prefix
end

function envoy_on_request(request_handle)
    local raw_path = request_handle:headers():get(":path") or ""
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
