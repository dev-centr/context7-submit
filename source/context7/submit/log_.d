module context7.submit.log_;

import std.algorithm : sort;
import std.datetime : Clock;
import std.file : DirEntry, dirEntries, exists, mkdirRecurse, remove, SpanMode, write;
import std.path : buildPath;
import std.process : environment;
import std.string : replace;

struct LogEvent
{
    string level;
    string message;
}

struct RunLog
{
    string path;
    string jsonlPath;
    LogEvent[] events;
}

string defaultLogDirectory()
{
    version (Windows)
    {
        auto base = environment.get("LOCALAPPDATA");
        if (base is null)
            base = environment.get("TEMP", ".");
        return buildPath(base, "ctx7-submit", "logs");
    }
    else version (OSX)
    {
        auto home = environment.get("HOME", ".");
        return buildPath(home, "Library", "Logs", "ctx7-submit");
    }
    else
    {
        auto state = environment.get("XDG_STATE_HOME");
        if (state is null)
            state = buildPath(environment.get("HOME", "."), ".local", "state");
        return buildPath(state, "ctx7-submit", "logs");
    }
}

RunLog openRunLog(string directory)
{
    RunLog log;
    try
    {
        if (!exists(directory))
            mkdirRecurse(directory);
        auto stamp = Clock.currTime.toISOExtString.replace(":", "-");
        log.path = buildPath(directory, stamp ~ ".log");
        log.jsonlPath = buildPath(directory, stamp ~ ".jsonl");
        pruneLogs(directory, 20);
    }
    catch (Exception)
    {
        log.path = null;
        log.jsonlPath = null;
    }
    return log;
}

void note(ref RunLog log, string level, string message)
{
    log.events ~= LogEvent(level, message);
}

void flush(ref RunLog log)
{
    if (log.path is null)
        return;
    try
    {
        string text = "== index ==\n§network\n== §network ==\n";
        string lines;
        foreach (event; log.events)
        {
            text ~= event.level ~ " " ~ event.message ~ "\n";
            lines ~= `{"level":"` ~ jsonEscape(event.level) ~ `","section":"network","message":"`
                ~ jsonEscape(event.message) ~ "\"}\n";
        }
        write(log.path, text);
        write(log.jsonlPath, lines);
    }
    catch (Exception)
    {
        log.path = null;
    }
}

private void pruneLogs(string directory, size_t keep)
{
    string[] names;
    foreach (DirEntry entry; dirEntries(directory, SpanMode.shallow))
    {
        if (entry.name.endsWithLog)
            names ~= entry.name;
    }
    sort(names);
    if (names.length <= keep)
        return;
    foreach (name; names[0 .. $ - keep])
    {
        try
            remove(name);
        catch (Exception)
        {
        }
        auto jsonl = name.length > 4 ? name[0 .. $ - 4] ~ ".jsonl" : null;
        if (jsonl.length && exists(jsonl))
        {
            try
                remove(jsonl);
            catch (Exception)
            {
            }
        }
    }
}

private bool endsWithLog(string name)
{
    import std.algorithm : endsWith;
    return name.endsWith(".log");
}

private string jsonEscape(string s)
{
    string o;
    foreach (char c; s)
    {
        if (c == '"' || c == '\\')
            o ~= '\\';
        o ~= c;
    }
    return o;
}
