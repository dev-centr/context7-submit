module context7.submit.cli;

import context7.submit.client;
import context7.submit.log_;
import context7.submit.target;
import context7.submit.version_;
import std.conv : to;
import std.json : JSONValue;
import std.string : strip;

enum Exit { ok = 0, failed = 1, usage = 2, auth = 3, rateLimit = 4 }

struct Io
{
    void delegate(string) out_;
    void delegate(string) err;
    string delegate(string) getEnv;
    string logDirectory;
}

private immutable usageText =
`ctx7-submit - send a documentation source to the Context7 index

This program does not install anything on this machine.

Usage:
  ctx7-submit <url> [options]

Options:
  --type <kind>              github, gitlab, bitbucket, git, website, openapi, llmstxt
  --private                  mark a Git repository as private
  --skip-version-filtering   skip version-specific documentation pages
  --generate-docs            generate docs from a private repository
  --website-base-url <url>   for a website, index only pages under this URL
  --base-url <url>           Context7 deployment (default https://context7.com)
  --json                     print one JSON result on stdout
  -v, --verbose              print the run log on stderr
  --quiet                    suppress the human summary
  --help, -h
  --version

The API key is read from CONTEXT7_API_KEY. A private Git token is read from
CONTEXT7_GIT_TOKEN. Neither value is accepted as a command argument.
Exit codes: 0 submitted or already indexed, 1 request failed, 2 usage,
3 authentication required, 4 rate limited.
`;

int run(string[] args, ref Io io, HttpPost post = null)
{
    bool json, verbose, quiet, help, version_;
    bool isPrivate, skipFiltering, generateDocs;
    string type, websiteBase, baseUrl, url;
    for (size_t i = 0; i < args.length; i++)
    {
        auto arg = args[i];
        string need()
        {
            if (i + 1 >= args.length)
                return null;
            return args[++i];
        }
        switch (arg)
        {
            case "--help", "-h":
                help = true;
                break;
            case "--version":
                version_ = true;
                break;
            case "--json":
                json = true;
                break;
            case "--quiet":
                quiet = true;
                break;
            case "-v", "--verbose":
                verbose = true;
                break;
            case "--private":
                isPrivate = true;
                break;
            case "--skip-version-filtering":
                skipFiltering = true;
                break;
            case "--generate-docs":
                generateDocs = true;
                break;
            case "--type":
                type = need();
                if (type is null)
                    return usage(io, "option --type needs a value");
                break;
            case "--website-base-url":
                websiteBase = need();
                if (websiteBase is null)
                    return usage(io, "option --website-base-url needs a value");
                break;
            case "--base-url":
                baseUrl = need();
                if (baseUrl is null)
                    return usage(io, "option --base-url needs a value");
                break;
            default:
                if (arg.startsWithDash)
                    return usage(io, "unknown option " ~ arg);
                if (url.length)
                    return usage(io, "only one URL is accepted");
                url = arg;
                break;
        }
    }

    if (help)
    {
        io.out_(usageText);
        return Exit.ok;
    }
    if (version_)
    {
        io.out_("ctx7-submit " ~ versionString ~ "\n");
        return Exit.ok;
    }
    if (url.length == 0)
        return usage(io, "a documentation source URL is required");

    auto envVerbose = io.getEnv("CTX7_SUBMIT_VERBOSE");
    auto ci = io.getEnv("CI");
    if (!verbose && envVerbose == "1")
        verbose = true;
    if (!verbose && !quiet && ci == "true")
        verbose = true;

    auto apiKey = io.getEnv("CONTEXT7_API_KEY");
    if (apiKey is null)
        apiKey = "";
    auto gitToken = io.getEnv("CONTEXT7_GIT_TOKEN");
    if (gitToken is null)
        gitToken = "";

    SubmitOptions options;
    options.isPrivate = isPrivate;
    options.hasPrivate = isPrivate;
    options.gitToken = gitToken;
    options.skipVersionFiltering = skipFiltering;
    options.hasSkipVersionFiltering = skipFiltering;
    options.generateDocs = generateDocs;
    options.hasGenerateDocs = generateDocs;
    options.websiteBaseUrl = websiteBase;

    auto directory = io.logDirectory.length ? io.logDirectory : defaultLogDirectory();
    auto log = openRunLog(directory);
    note(log, "info", "submit " ~ url);

    auto result = submitSource(SubmitRequest(url, type, options, apiKey.strip, baseUrl), post);
    note(log, result.ok ? "info" : "error", result.message);
    flush(log);

    int code = Exit.ok;
    if (!result.ok)
    {
        if (result.errorCode == "validation_error")
            code = Exit.usage;
        else if (result.errorCode == "unauthorized")
            code = Exit.auth;
        else if (result.errorCode == "rate_limit_exceeded")
            code = Exit.rateLimit;
        else
            code = Exit.failed;
    }

    if (json)
        io.out_(resultJson(result, code, log.path));
    else if (result.ok && result.libraryName.length)
        io.out_(result.libraryName ~ "\n");

    if (!json && !quiet)
    {
        io.err((result.ok ? "Submitted. " : "Failed. ") ~ result.message ~ "\n");
        if (log.path.length)
            io.err(log.path ~ "\n");
    }
    else if (!result.ok)
        io.err(result.message ~ "\n");
    if (verbose && log.path.length)
    {
        foreach (event; log.events)
            io.err(event.level ~ " " ~ event.message ~ "\n");
    }
    return code;
}

private bool startsWithDash(string arg)
{
    import std.algorithm : startsWith;
    return arg.startsWith("-");
}

private int usage(ref Io io, string reason)
{
    io.err(reason ~ "\n" ~ usageText);
    return Exit.usage;
}

private string resultJson(SubmitResult result, int code, string logPath)
{
    JSONValue doc;
    doc["outcome"] = result.ok ? (result.alreadyExists ? "alreadyIndexed" : "submitted") : "failed";
    doc["exitCode"] = code;
    doc["libraryName"] = result.libraryName;
    doc["version"] = result.versionText;
    doc["kind"] = result.kind;
    doc["message"] = result.message;
    doc["error"] = result.errorCode;
    doc["status"] = result.status;
    JSONValue[] changes;
    if (result.ok && result.libraryName.length)
        changes ~= JSONValue(result.libraryName);
    doc["changes"] = JSONValue(changes);
    JSONValue[] attention;
    if (result.alreadyExists)
        attention ~= JSONValue("already indexed");
    doc["attention"] = JSONValue(attention);
    doc["logPath"] = logPath;
    return doc.toPrettyString ~ "\n";
}

unittest
{
    import std.file : rmdirRecurse, tempDir;
    import std.string : indexOf;
    import std.path : buildPath;

    string outText, errText;
    Io io;
    io.out_ = (string s) { outText ~= s; };
    io.err = (string s) { errText ~= s; };
    io.getEnv = (string k) {
        if (k == "CONTEXT7_API_KEY")
            return "ctx7sk-test";
        if (k == "CONTEXT7_GIT_TOKEN")
            return "secret-token";
        return null;
    };
    io.logDirectory = buildPath(tempDir, "ctx7-submit-test-logs");
    auto code = run(["https://github.com/acme/docs", "--json"], io,
        (string url, const(char)[] body, string apiKey, out int status, out string failure) {
            status = 200;
            failure = null;
            assert(body.indexOf("secret-token") >= 0);
            return `{"libraryName":"/acme/docs","message":"Repository submitted successfully"}`;
        });
    assert(code == 0);
    assert(outText.indexOf("\"outcome\": \"submitted\"") >= 0 || outText.indexOf("\"outcome\":\"submitted\"") >= 0);
    assert(errText.indexOf("secret-token") < 0);
    assert(outText.indexOf("secret-token") < 0);
    import std.file : exists;
    if (exists(io.logDirectory))
        rmdirRecurse(io.logDirectory);

    outText = null;
    errText = null;
    Io bare;
    bare.out_ = (string s) { outText ~= s; };
    bare.err = (string s) { errText ~= s; };
    bare.getEnv = (string) => null;
    bare.logDirectory = io.logDirectory;
    assert(run([], bare) == Exit.usage);
}
