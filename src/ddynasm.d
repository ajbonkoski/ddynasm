import std.stdio;
import std.file;
import std.path;
import std.string;
import std.conv;
import std.regex;
import std.algorithm;
import std.process;

enum JitHeaders = q{
  import ddynasm.dasm_x86;
  import std.exception;
  byte b(T)(T v)
  {
    enforce((v&(~0xff)) == 0);
    return cast(byte)(v&0xff);
  }
};

interface LineHandler
{
  void handleLine(string line);
}

LineHandler[] lhStack = [new TopLevelDispatch()];
void poplhStack() { assert(lhStack.length > 0); lhStack = lhStack[0..$-1]; }

auto drop(string s, ulong n){
  if(s.length >= n) return s[n..$];
  else return "";
}

class PreprocIf : LineHandler
{
  bool inside = false;
  void handleLine(string line)
  {
    if(!inside) {
      assert(line.startsWith("#if"));
      string cond = line.drop(3).strip;
      writefln("static if(%s) {", cond);
      inside = true;
    }

    else if(line.startsWith("#error")) {
      line = line.strip;
      string msg = line.drop(6).strip;
      writefln("    static assert(%s);", msg);
    }

    else if(line.startsWith("#endif")) {
      writefln("}");
      poplhStack();
    }

    else {
      writeln(line);
    }

  }
}

class PreprocDefine : LineHandler
{
  void handleLine(string line)
  {
    assert(line.startsWith("#define"));
    auto l = line.drop(7).strip;
    auto ls = l.split(" ");
    assert(ls.length == 2);
    writefln("alias %s %s;", ls[1], ls[0]);
    poplhStack();
  }
}

class PreprocHash : LineHandler
{
  void handleLine(string line)
  {
    assert(line.startsWith("# "));
    auto l = line.drop(2).strip;
    auto ls = l.split(" ");
    assert(ls.length > 0);
    uint lineno = ls[0].to!uint;
    string msg = l.drop(ls[0].length).strip;
    writefln("//lineno=%d, msg=%s", lineno, msg);
    poplhStack();
  }
}

class ActionList : LineHandler
{
  int count = 0;
  void handleLine(string line)
  {
    switch(count) {
      case 0:
        assert(line.startsWith("//|.actionlist"));
        break;
      case 1:
        auto m = match(line, r"^\s*static\s*const\s*unsigned\s*char\s*([a-z]+)\s*\[\s*(\d+)\s*\]\s*=\s*\{\s*$");
        assert(m);
        writefln("const byte[%s] %s = [", m.captures[2], m.captures[1]);
        break;
      case 2:
        if(line.strip == "};") {
          writeln("];");
          poplhStack();
          return;
        } else {
          line.split(",").map!(a => a.length>0 ? a~".b" : a).join(",").writeln;
          return;
        }

      default:
        stderr.writeln("Error: reached unexpected state in ActionList");
        poplhStack();
        return;
    }

    count++;
  }
}

class TopLevelDispatch : LineHandler
{
  void handleLine(string line)
  {
    LineHandler new_lh = null;

    if(line.startsWith("#if"))
      new_lh = new PreprocIf;

    else if(line.startsWith("#define"))
      new_lh = new PreprocDefine;

    else if(line.startsWith("# "))
      new_lh = new PreprocHash;

    else if(line.startsWith("//|.actionlist"))
      new_lh = new ActionList;


    if(new_lh !is null) {
      lhStack ~= new_lh;
      new_lh.handleLine(line);
    }
    else {
      writeln(line);
    }

  }
}

string readFirstLine(string fname)
{
  auto f = File(fname, "r");
  foreach(line; f.byLine)
    return line.idup;
  return "";
}

int main(string[] argv)
{
  auto name = argv[0];
  argv = argv[1..$];
  if(argv.length != 1) {
    stderr.writeln("ddynasm.d <dasd-file>");
    return -1;
  }

  string first = argv[0].readFirstLine;

  // construct some paths
  auto BIN_DIR = name.absolutePath.buildNormalizedPath.dirName;
  auto SRC_DYNASM_DIR = buildNormalizedPath(BIN_DIR, "../src/dynasm");

  auto CMD = "lua %s/dynasm.lua %s".format(SRC_DYNASM_DIR, argv[0]);
  auto res = executeShell(CMD);
  if(res.status != 0) {
    stderr.writeln("error: failed to execute dynasm lua script");
    return -1;
  }

  if(first.startsWith("module ")) first.writeln;
  JitHeaders.writeln;
  foreach(line; res.output.splitLines) {
    if(line.startsWith("module ")) "".writeln;
    else lhStack[$-1].handleLine(line.idup);
  }

  return 0;
}
