module context7.submit.client;

import context7.submit.target;
import std.json : JSONException, JSONValue, parseJSON;
import std.string : indexOf;

struct SubmitRequest
{
    string url;
    string kind;
    SubmitOptions options;
    string apiKey;
    string baseUrl = "https://context7.com";
}

struct SubmitResult
{
    bool ok;
    bool alreadyExists;
    int status;
    string libraryName;
    string versionText;
    string message;
    string errorCode;
    string kind;
}

alias HttpPost = string delegate(string url, const(char)[] jsonBody, string apiKey, out int status, out string failure);

SubmitResult submitSource(SubmitRequest req, HttpPost post = null)
{
    SubmitResult result;
    ResolvedTarget target;
    try
        target = resolveSubmitTarget(req.url, parseSubmitKind(req.kind), req.options);
    catch (SubmitError e)
    {
        result.errorCode = "validation_error";
        result.message = e.msg;
        return result;
    }
    result.kind = target.kind;

    if (req.apiKey.length == 0)
    {
        result.status = 401;
        result.errorCode = "unauthorized";
        result.message = "Authentication required. Set CONTEXT7_API_KEY (https://context7.com/dashboard).";
        return result;
    }

    auto base = req.baseUrl.length ? req.baseUrl : "https://context7.com";
    while (base.endsWithChar('/'))
        base = base[0 .. $ - 1];
    auto endpoint = base ~ target.endpointPath;
    auto payload = target.body.toString;

    int status;
    string failure;
    string body;
    if (post is null)
        body = curlPost(endpoint, payload, req.apiKey, status, failure);
    else
        body = post(endpoint, payload, req.apiKey, status, failure);

    if (failure.length)
    {
        result.errorCode = "network_error";
        result.message = failure;
        return result;
    }
    return interpretResponse(status, body, target.kind);
}

SubmitResult interpretResponse(int status, string body, string kind)
{
    SubmitResult result;
    result.status = status;
    result.kind = kind;
    if (body.length)
    {
        try
        {
            auto json = parseJSON(body);
            if (auto name = "libraryName" in json)
                result.libraryName = name.str;
            if (auto versionText = "version" in json)
                result.versionText = versionText.str;
            if (auto message = "message" in json)
                result.message = message.str;
            if (auto errorCode = "error" in json)
                result.errorCode = errorCode.str;
        }
        catch (JSONException)
        {
            result.message = "Context7 returned a response that was not JSON.";
            result.errorCode = "invalid_response";
        }
    }
    if (status == 409)
    {
        result.ok = true;
        result.alreadyExists = true;
        if (result.message.length == 0)
            result.message = "This source is already indexed.";
        return result;
    }
    if (status >= 200 && status < 300)
    {
        result.ok = true;
        if (result.message.length == 0)
            result.message = "Documentation source submitted.";
        return result;
    }
    result.ok = false;
    if (result.errorCode.length == 0)
        result.errorCode = status == 401 || status == 403 ? "unauthorized"
            : status == 429 ? "rate_limit_exceeded"
            : "http_error";
    if (result.message.length == 0)
        result.message = "Context7 rejected the submission (HTTP " ~ statusText(status) ~ ").";
    return result;
}

private string statusText(int status)
{
    import std.conv : to;
    return to!string(status);
}

private bool endsWithChar(string s, char c)
{
    return s.length > 0 && s[$ - 1] == c;
}

string curlPost(string url, string jsonBody, string apiKey, out int status, out string failure)
{
    import std.array : appender;
    import std.net.curl : CurlException, HTTP;

    status = 0;
    failure = null;
    auto http = HTTP(url);
    http.method = HTTP.Method.post;
    http.addRequestHeader("Authorization", "Bearer " ~ apiKey);
    http.addRequestHeader("Accept", "application/json");
    http.addRequestHeader("X-Context7-Source", "dev-centr/context7-submit");
    auto buf = appender!(ubyte[]);
    http.onReceive = (ubyte[] data) {
        buf.put(data);
        return data.length;
    };
    http.setPostData(jsonBody, "application/json");
    try
        http.perform();
    catch (CurlException)
    {
        failure = "Could not reach Context7.";
        return null;
    }
    status = http.statusLine.code;
    return cast(string) buf.data.idup;
}

unittest
{
    string seenUrl, seenBody, seenKey;
    auto result = submitSource(SubmitRequest("https://github.com/acme/docs", null,
        SubmitOptions(false, false, "secret-token"), "ctx7sk-test"),
        (string url, const(char)[] body, string apiKey, out int status, out string failure) {
            seenUrl = url;
            seenBody = body.idup;
            seenKey = apiKey;
            status = 200;
            failure = null;
            return `{"libraryName":"/acme/docs","message":"Repository submitted successfully"}`;
        });
    assert(result.ok);
    assert(result.libraryName == "/acme/docs");
    assert(seenUrl == "https://context7.com/api/v2/add/repo/github");
    assert(seenKey == "ctx7sk-test");
    assert(seenBody.indexOf("secret-token") >= 0);

    auto dup = interpretResponse(409, `{"message":"already there","libraryName":"/acme/docs"}`, "github");
    assert(dup.ok && dup.alreadyExists);

    auto missing = submitSource(SubmitRequest("https://dlang.org/spec/spec.html"));
    assert(!missing.ok);
    assert(missing.errorCode == "unauthorized");
}
