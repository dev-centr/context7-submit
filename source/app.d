module app;

import context7.submit.cli;
import std.process : environment;
import std.stdio : stderr, stdout;

int main(string[] args)
{
    Io io;
    io.out_ = (string s) { stdout.write(s); stdout.flush(); };
    io.err = (string s) { stderr.write(s); stderr.flush(); };
    io.getEnv = (string k) => environment.get(k, null);
    return run(args[1 .. $], io);
}
