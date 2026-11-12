module context7.submit.target;

import std.algorithm : endsWith, startsWith;
import std.exception : basicExceptionCtors;
import std.json : JSONValue;
import std.string : indexOf, lastIndexOf, strip, toLower;

class SubmitError : Exception
{
    mixin basicExceptionCtors;
}

struct UrlParts
{
    string original;
    string scheme;
    string host;
    string path;
}

struct ResolvedTarget
{
    string kind;
    string endpointPath;
    JSONValue body;
}

struct SubmitOptions
{
    bool isPrivate;
    bool hasPrivate;
    string gitToken;
    bool skipVersionFiltering;
    bool hasSkipVersionFiltering;
    bool generateDocs;
    bool hasGenerateDocs;
    string websiteBaseUrl;
}

private immutable string[] submitKinds = [
    "github", "gitlab", "bitbucket", "git", "website", "openapi", "llmstxt"
];

UrlParts parseHttpUrl(string raw)
{
    auto s = raw.strip;
    auto schemeEnd = s.indexOf("://");
    if (schemeEnd < 1)
        throw new SubmitError("Invalid URL: \"" ~ raw ~ "\"");
    auto rest = s[schemeEnd + 3 .. $];
    if (rest.length == 0)
        throw new SubmitError("Invalid URL: \"" ~ raw ~ "\"");
    auto slash = rest.indexOf("/");
    auto host = slash < 0 ? rest : rest[0 .. slash];
    auto path = slash < 0 ? "/" : rest[slash .. $];
    auto at = host.lastIndexOf("@");
    if (at >= 0)
        host = host[at + 1 .. $];
    auto colon = host.indexOf(":");
    if (colon >= 0)
        host = host[0 .. colon];
    if (host.length == 0)
        throw new SubmitError("Invalid URL: \"" ~ raw ~ "\"");
    return UrlParts(s, s[0 .. schemeEnd].toLower, host.toLower, path);
}

private bool hostMatches(string host, string domain)
{
    return host == domain || host.endsWith("." ~ domain);
}

string detectSubmitKind(UrlParts parsed)
{
    auto path = parsed.path.toLower;
    if (path.endsWith("llms.txt") || path.endsWith("/llms-full.txt"))
        return "llmstxt";
    if (path.indexOf("openapi") >= 0 &&
        (path.endsWith(".json") || path.endsWith(".yaml") || path.endsWith(".yml")))
        return "openapi";
    if (hostMatches(parsed.host, "github.com"))
        return "github";
    if (hostMatches(parsed.host, "gitlab.com"))
        return "gitlab";
    if (hostMatches(parsed.host, "bitbucket.org"))
        return "bitbucket";
    if (parsed.scheme == "git" || path.endsWith(".git"))
        return "git";
    return "website";
}

string parseSubmitKind(string value)
{
    if (value.length == 0)
        return null;
    auto normalized = value.toLower;
    foreach (kind; submitKinds)
        if (normalized == kind)
            return kind;
    throw new SubmitError("Invalid --type \"" ~ value ~ "\". Expected one of: " ~ kindList());
}

private string kindList()
{
    string s;
    foreach (i, kind; submitKinds)
    {
        if (i)
            s ~= ", ";
        s ~= kind;
    }
    return s;
}

ResolvedTarget resolveSubmitTarget(string url, string kind, SubmitOptions options = SubmitOptions.init)
{
    auto parsed = parseHttpUrl(url);
    auto resolved = kind.length ? kind : detectSubmitKind(parsed);
    if (options.websiteBaseUrl.length && resolved != "website")
        throw new SubmitError("--website-base-url applies only to a website source.");

    JSONValue body;
    string endpoint;
    if (resolved == "website")
    {
        endpoint = "/api/v2/add/website";
        body["websiteUrl"] = parsed.original;
        if (options.websiteBaseUrl.length)
            body["websiteBaseUrl"] = parseHttpUrl(options.websiteBaseUrl).original;
    }
    else if (resolved == "openapi")
    {
        endpoint = "/api/v2/add/openapi";
        body["openApiUrl"] = parsed.original;
    }
    else if (resolved == "llmstxt")
    {
        endpoint = "/api/v2/add/llmstxt";
        body["llmstxtUrl"] = parsed.original;
    }
    else
    {
        endpoint = resolved == "github" ? "/api/v2/add/repo/github"
            : resolved == "gitlab" ? "/api/v2/add/repo/gitlab"
            : resolved == "bitbucket" ? "/api/v2/add/repo/bitbucket"
            : "/api/v2/add/repo/git";
        body["docsRepoUrl"] = parsed.original;
        if (options.hasPrivate)
            body["private"] = options.isPrivate;
        if (options.gitToken.length)
            body["gitToken"] = options.gitToken;
        if (options.hasSkipVersionFiltering)
            body["skipVersionFiltering"] = options.skipVersionFiltering;
        if (options.hasGenerateDocs)
            body["generateDocs"] = options.generateDocs;
    }
    return ResolvedTarget(resolved, endpoint, body);
}

unittest
{
    assert(detectSubmitKind(parseHttpUrl("https://github.com/vercel/next.js")) == "github");
    assert(detectSubmitKind(parseHttpUrl("https://gitlab.com/owner/repo")) == "gitlab");
    assert(detectSubmitKind(parseHttpUrl("https://bitbucket.org/owner/repo")) == "bitbucket");
    assert(detectSubmitKind(parseHttpUrl("https://docs.example.com/llms.txt")) == "llmstxt");
    assert(detectSubmitKind(parseHttpUrl("https://api.example.com/openapi.json")) == "openapi");
    assert(detectSubmitKind(parseHttpUrl("https://codeberg.org/owner/repo")) == "website");
    assert(detectSubmitKind(parseHttpUrl("https://codeberg.org/owner/repo.git")) == "git");
    assert(detectSubmitKind(parseHttpUrl("https://dlang.org/spec/spec.html")) == "website");

    auto gh = resolveSubmitTarget("https://github.com/vercel/next.js", null, SubmitOptions(true, true, "tok"));
    assert(gh.kind == "github");
    assert(gh.endpointPath == "/api/v2/add/repo/github");
    assert(gh.body["docsRepoUrl"].str == "https://github.com/vercel/next.js");
    assert(gh.body["private"].boolean);
    assert(gh.body["gitToken"].str == "tok");

    auto site = resolveSubmitTarget("https://dlang.org/spec/spec.html", "website",
        SubmitOptions(false, false, null, false, false, false, false, "https://dlang.org/spec/"));
    assert(site.body["websiteBaseUrl"].str == "https://dlang.org/spec/");

    import std.exception : assertThrown;
    assertThrown!SubmitError(resolveSubmitTarget("not-a-url", null));
    assertThrown!SubmitError(resolveSubmitTarget("https://github.com/vercel/next.js", null,
        SubmitOptions(false, false, null, false, false, false, false, "https://dlang.org/spec/")));
    assert(parseSubmitKind("GitHub") == "github");
    assertThrown!SubmitError(parseSubmitKind("notion"));
}
