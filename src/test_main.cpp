#include <string>
#include <thread>


extern "C" {
#include "config.h"
#include "sys.h"
#include "erl_vm.h"
#include "global.h"
}

void run_erlang()
{
    const char *args[] = {
        "test_main",
        "-sbwt",
        "none",
        "--",
        "-root",
        "/home/dominicletz/dDrive",
        "-progname",
        "erl",
        "--",
        "-home",
        "/home/dominicletz",
        "--",
        "-kernel",
        "shell_history",
        "enabled",
        "--",
        "-heart",
        "-pa",
        "/home/dominicletz/.config/ddrive/update-1.2.1",
        "-kernel",
        "inet_dist_use_interface",
        "{127,0,0,1}",
        "-elixir",
        "ansi_enabled",
        "true",
        "-noshell",
        "-s",
        "elixir",
        "start_cli",
        "-mode",
        "embedded",
        "-setcookie",
        "EFIXW6GFCGFWOQCYTPRFXNR2JRYN6BJVX7FTOOLWONYFUQF46PVQ====",
        "-name",
        "ddrive_7598@127.0.0.1",
        "-config",
        "/home/dominicletz/dDrive/releases/1.2.1/sys",
        "-boot",
        "/home/dominicletz/dDrive/releases/1.2.1/start",
        "-boot_var",
        "RELEASE_LIB",
        "/home/dominicletz/dDrive/lib",
        "--",
        "--",
        "-extra",
        "--no-halt",
    };

    erl_start(sizeof(args) / sizeof(args[0]), (char **)args);
}

int main(int argc, char *argv[])
{
    char *path = getenv("PATH");

    auto app = std::string("dDrive");
    auto home_dir = std::string("/home/dominicletz/");
    auto root_dir = home_dir.append("dDrive/");
    auto bin_dir = root_dir.append("erts-12.0/bin/");

    auto env_bin_dir = std::string("BINDIR=").append(bin_dir);
    auto env_path = std::string("PATH=").append(path).append(":").append(bin_dir);
    auto app_icon = std::string("WX_APP_ICON=").append(root_dir).append("lib/ddrive-1.2.1/priv/diode.png");

    chdir("/home/dominicletz/dDrive");
    putenv((char *)env_bin_dir.c_str());
    putenv((char *)env_path.c_str());
    putenv((char *)"WX_APP_TITLE=dDrive");
    putenv((char *)app_icon.c_str());

    std::thread erlang(run_erlang);
    erlang.join();
    // run_erlang();
    exit(0);
}