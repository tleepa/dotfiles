#!/usr/bin/python3

"""
msysGit to Unix socket proxy
============================

This small script is intended to help use msysGit sockets with the new Windows Linux Subsystem (aka Bash for Windows).

It was specifically designed to pass SSH keys from the KeeAgent module of KeePass secret management application to the
ssh utility running in the WSL (it only works with Linux sockets). However, my guess is that it will have uses for other
applications as well.

In order to efficiently use it, I add it at the end of the ~/.bashrc file, like this:
    export SSH_AUTH_SOCK="/tmp/.ssh-auth-sock"
    ~/bin/msysgit3unix-socket.py /mnt/c/Users/User/keeagent.sock:$SSH_AUTH_SOCK

Command line usage: msysgit3unix-socket.py [-h] [--downstream-buffer-size N]
                                           [--upstream-buffer-size N] [--listen-backlog N]
                                           [--timeout N] [--pidfile FILE]
                                           source:destination [source:destination ...]

Positional arguments:
  source:destination    A pair of a source msysGit and a destination Unix
                        sockets.

Optional arguments:
  -h, --help            show this help message and exit
  --downstream-buffer-size N
                        Maximum number of bytes to read at a time from the
                        Unix socket.
  --upstream-buffer-size N
                        Maximum number of bytes to read at a time from the
                        msysGit socket.
  --listen-backlog N    Maximum number of simultaneous connections to the Unix
                        socket.
  --timeout N           Timeout.
  --pidfile FILE        Where to write the PID file.
"""

import argparse
import asyncio
import os
import re
import signal
import sys
import datetime
import psutil


def logmsg(txt):
    ts = str(datetime.datetime.now())
    with open("/tmp/msysgit3unix-socket.log", "a") as lf:
        lf.writelines(f"[{ts}] {txt}\n")

    if config.do_not_daemonize:
        print(f"***** [{ts}] {txt}", flush=True)


class SocketConvertServer:
    """
    This is the "server" listening for connections on the Unix socket.
    """

    def __init__(self, is_cygwin, upstream_socket_path):
        self.is_cygwin = is_cygwin
        self.upstream_socket_path = upstream_socket_path
        # (self.port, self.guid) = self.load_socket_file(upstream_socket_path)
        self.port = -1
        self.guid = None

    def load_socket_file(self, path):
        with open(path, "r") as f:
            line = f.readline()

        m = re.search(r">(\d+)(?: s)? ([\w\d-]+)", line)

        if self.is_cygwin:
            guid_str = m.group(2)
            guid_bytes = b"".join([bytes.fromhex(p)[::-1] for p in guid_str.split("-")])
        else:
            guid_bytes = None

        return int(m.group(1)), guid_bytes

    async def connect_upstream(self):
        (reader, writer) = await asyncio.wait_for(asyncio.open_connection("127.0.0.1", self.port), 1)

        if self.is_cygwin:
            writer.write(self.guid)

            try:
                data = await asyncio.wait_for(reader.read(16), 1)
                if data != self.guid:
                    raise Exception("GUID not match")
            except:
                writer.close()
                raise

            pid = os.getpid()
            uid = os.geteuid()
            gid = os.getegid()

            logmsg(f"local: P:{pid} U:{uid} G:{gid}")

            byte_order = "little"
            data = pid.to_bytes(4, byte_order)
            data += uid.to_bytes(4, byte_order)
            data += gid.to_bytes(4, byte_order)

            writer.write(data)

            data = await reader.read(12)
            pid = int.from_bytes(data[:4], byte_order)
            uid = int.from_bytes(data[4:8], byte_order)
            gid = int.from_bytes(data[8:], byte_order)

            logmsg(f"remote: P:{pid} U:{uid} G:{gid}")

        logmsg("upstream (WIN) connected")

        return reader, writer

    async def handle_connected(self, reader, writer):
        logmsg("Connection from WSL (downstream) detected, trying to get data from WIN socket")

        try:
            (self.port, self.guid) = self.load_socket_file(self.upstream_socket_path)
            (upstream_reader, upstream_writer) = await self.connect_upstream()
        except Exception as e:
            writer.close()
            logmsg(f"Connect to upstream (WIN) failed:{e}")
            return

        async def handle_up():
            while True:
                data = await reader.read(config.downstream_buffer_size)
                if not data:
                    break
                upstream_writer.write(data)

            logmsg("down (WSL) closed")
            upstream_writer.close()

        async def handle_down():
            while True:
                data = await upstream_reader.read(config.upstream_buffer_size)
                if not data:
                    break
                writer.write(data)

            logmsg("up (WIN) closed")
            writer.close()

        await asyncio.gather(handle_up(), handle_down())
        logmsg("Connection from WSL (downstream) closed")


def build_config():
    class ProxyAction(argparse.Action):
        def __call__(self, parser, namespace, values, option_string=None):
            proxies = []
            for value in values:
                src_dst = value.partition(':')
                if src_dst[1] == b'':
                    raise parser.error(b'Unable to parse sockets proxy pair "%s".' % value)
                proxies.append([src_dst[0], src_dst[2]])
            setattr(namespace, self.dest, proxies)

    parser = argparse.ArgumentParser(
        description='Transforms msysGit/Cygwin compatible sockets to Unix sockets for the Windows Linux Subsystem.')
    parser.add_argument('--do-not-daemonize', action='store_true',
                        help="Keep running in foreground.")
    parser.add_argument('--cygwin', action='store_true',
                        help="Is cygwin or msysgit socket file")
    parser.add_argument('--downstream-buffer-size', default=8192, type=int, metavar='N',
                        help='Maximum number of bytes to read at a time from the Unix socket.')
    parser.add_argument('--upstream-buffer-size', default=8192, type=int, metavar='N',
                        help='Maximum number of bytes to read at a time from the msysGit socket.')
    parser.add_argument('--listen-backlog', default=100, type=int, metavar='N',
                        help='Maximum number of simultaneous connections to the Unix socket.')
    parser.add_argument('--timeout', default=60, type=int, help='Timeout.', metavar='N')
    parser.add_argument('--pidfile', default='/tmp/msysgit3unix-socket.pid', metavar='FILE',
                        help='Where to write the PID file.')
    parser.add_argument('proxies', nargs='+', action=ProxyAction, metavar='source:destination',
                        help='A pair of a source msysGit and a destination Unix sockets.')
    return parser.parse_args()


def daemonize():
    try:
        pid = os.fork()
        if pid > 0:
            sys.exit()
    except OSError:
        sys.stderr.write(b'Fork #1 failed.')
        logmsg("Fork #1 failed")
        sys.exit(1)

    os.chdir(b'/')
    os.setsid()
    os.umask(0)

    try:
        pid = os.fork()
        if pid > 0:
            sys.exit()
    except OSError:
        sys.stderr.write(b'Fork #2 failed.')
        logmsg("Fork #2 failed")
        sys.exit(1)

    sys.stdout.flush()
    sys.stderr.flush()

    si = open('/dev/null', 'r')
    so = open('/dev/null', 'a+')
    se = open('/dev/null', 'a+')
    os.dup2(si.fileno(), sys.stdin.fileno())
    os.dup2(so.fileno(), sys.stdout.fileno())
    os.dup2(se.fileno(), sys.stderr.fileno())

    pid = str(os.getpid())
    with open(config.pidfile, 'w+') as f:
        f.write(f"{pid}\n")


def cleanup():
    logmsg("Cleaning up (socket and pidfile)")
    for pair in config.proxies:
        tmp_file = pair[1]
        if os.path.exists(tmp_file):
            os.remove(tmp_file)
    if os.path.exists(config.pidfile):
        os.remove(config.pidfile)


def signal_handler(sig_num, stack_frame):
    logmsg(f"Received signal: {sig_num}")
    cleanup()
    logmsg("Exiting")
    sys.exit(0)


if __name__ == '__main__':
    config = build_config()
    myself = psutil.Process()

    if os.path.exists(config.pidfile):

        logmsg(f'{myself.name()}: Pidfile "{config.pidfile}" already exists, checking if process is still running...')

        with open(config.pidfile, "r") as pidfile:
            old_pid = int(pidfile.read())

        try:
            running_process = psutil.Process(old_pid)
        except psutil.NoSuchProcess:
            running_process = None
            logmsg(f"No process with PID {old_pid} is running, cleaning up.")
            cleanup()

        if running_process:
            logmsg(f"Process with PID {old_pid} is running ({running_process.name()})")
            if running_process.name() == myself.name():
                logmsg("It's me already, exiting...")
                sys.stdout.write(f"{myself.name()}: Serving already: PID: {old_pid}\n")
                sys.exit(0)
            else:
                logmsg(f"It's someone else ({running_process.name()}), cleaning up.")
                cleanup()
    else:
        logmsg(f"{myself.name()}: Starting up.")
        sys.stdout.write(f"{myself.name()}: Starting up.\n")

    if not config.do_not_daemonize:
        daemonize()

    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)

    def run_servers():
        tasks = []
        for pair in config.proxies:
            server = SocketConvertServer(config.cygwin, pair[0])
            tasks.append(asyncio.start_unix_server(server.handle_connected, pair[1]))

        return asyncio.gather(*tasks)

    loop = asyncio.get_event_loop()
    servers = loop.run_until_complete(run_servers())

    logmsg("Servers started.")

    try:
        loop.run_forever()
    except KeyboardInterrupt:
        pass

    logmsg("Closing servers")
    for server in servers:
        server.close()

    loop.run_until_complete(asyncio.gather(*[server.wait_closed() for server in servers]))
    loop.close()

    cleanup()
