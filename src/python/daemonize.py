#!/usr/bin/env python2

# Authors:  Jiri Jaburek  <jjaburek@redhat.com>
#
# Description: Daemonization backend for rlDaemonize
#
# Copyright (c) 2012 Red Hat, Inc. All rights reserved. This copyrighted
# material is made available to anyone wishing to use, modify, copy, or
# redistribute it subject to the terms and conditions of the GNU General
# Public License v.2.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

from __future__ import print_function
import os, sys

from pwd import getpwnam
from grp import getgrnam

from optparse import OptionParser
from shlex import shlex

def file_write(filename, content):
    fd = open(filename, 'w')
    fd.write(content + '\n')
    fd.close()

def close_all_fds():
    try:
        maxfd = os.sysconf('SC_OPEN_MAX')  # same as _SC_OPEN_MAX in C
    except:
        maxfd = 1024

    for fd in range(0, maxfd):
        try:
            os.close(fd)
        except OSError:
            pass

# daemonize `command' (list) with arguments,
# optionally change argv[0] to `alias',
#            write child pid to file named `pidfile',
#            fully daemonize or just background (fork) - `true_daemon',
#            change effective+real user/group to `su' (list, user and group)
#            (when true_daemon=True) redirect stdin/out/err to filenames
#              specified in ioredir vector (list),
def daemonize(command, alias=None, pidfile=None, true_daemon=True, su=None, ioredir=None):
    if not alias:
        alias = command[0]

    if not true_daemon:
        pid = os.fork()
        if (pid != 0):
            # parent, write pidfile and _exit,
            # avoiding possible double cleanups/flushes
            if pidfile:
                file_write(pidfile, str(pid))
            os._exit(0)
        else:
           # child, simply execute
           os.execvp(command[0],[alias]+command[1:])

    else:
        pid = os.fork()
        if (pid != 0):
            # parent, just exit, since final pid depends on the second fork
            os._exit(0)
        else:
            os.setsid()
            pid = os.fork()
            if (pid != 0):
                # parent of the second child
                if pidfile:
                    file_write(pidfile, str(pid))
                os._exit(0)
            else:
                # second child, real daemon!

                os.chdir('/')

                # change real and effective uid/gid of a process
                if su:
                    uid = getpwnam(su[0]).pw_uid
                    gid = getgrnam(su[1]).gr_gid
                    os.setgroups([])
                    os.setregid(gid, gid)
                    os.setreuid(uid, uid)

                # pre-create possible in/out files with default umask,
                # with original stderr (in case of errors), but with new uid/gid
                if ioredir:
                    os.open(ioredir[0], os.O_RDWR)
                    os.open(ioredir[1], os.O_RDWR | os.O_CREAT | os.O_TRUNC, 0666)
                    os.open(ioredir[2], os.O_RDWR | os.O_CREAT | os.O_TRUNC, 0666)

                os.umask(0)

                close_all_fds()
                if ioredir:
                    for ioport in ioredir:
                        os.open(ioport, os.O_RDWR)
                else:
                    os.open(os.devnull, os.O_RDWR)
                    os.dup2(0,1)
                    os.dup2(0,2)

                # execute
                os.execvp(command[0],[alias]+command[1:])


# argument parsing
def error(msg):
    print("error: " + str(msg), file=sys.stderr)
    sys.exit(1)

parser = OptionParser(usage='%prog [options] COMMAND')
parser.add_option('--alias', action='store', type='string', metavar='NAME',
                  dest='alias', help='specify custom argv[0]')
parser.add_option('--background', action='store_true',
                  dest='background', help='background (fork) only, nothing else')
parser.add_option('--su', action='store', type='string', metavar='USER:GROUP',
                  dest='su', help='run daemon under another user')
parser.add_option('--ioredir', action='store', type='string', metavar='IN,OUT,ERR',
                  dest='ioredir', help='redirect std{in,out,err} of the daemon to files')
parser.add_option('--pidfile', action='store', type='string', metavar='FILE',
                  dest='pidfile', help='write daemon pid to a file')

(opts, args) = parser.parse_args()

# additional parsing
if opts.su:
    su = opts.su.split(':')
else:
    su = None
if opts.ioredir:
    ioredir = opts.ioredir.split(',')
else:
    ioredir = None

# sanity checks
if not args:
    error("no COMMAND specified")
if len(args) > 1:
    error("COMMAND can be only one argument, quote it")
if opts.su:
    if len(su) != 2:
        error("wrong --su argument specification")
    for i in su:
        if not i:
            error("wrong --su argument specification")
if opts.ioredir:
    if len(ioredir) != 3:
        error("wrong --ioredir argument specification")
    for i in ioredir:
        if not i:
            error("wrong --ioredir argument specification")

# shell-expand the COMMAND into list
lex = shlex(args[0])
lex.whitespace_split = True
args = list(lex)

# input parsing finished
daemonize(args, alias=opts.alias, pidfile=opts.pidfile,
          true_daemon=(not opts.background), su=su, ioredir=ioredir)
