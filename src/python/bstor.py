#!/usr/bin/python

from optparse import OptionParser
import sys
import os
import ConfigParser

class Storage(object):
  SUBDIR="storage"
  def __init__(self, section, namespace):
    self.section = section
    self.namespace = namespace

  def __obtain_dir(self):
    beakerlib_dir = os.environ["BEAKERLIB_DIR"]
    if beakerlib_dir == "":
      print >> sys.stderr, "bstor: BEAKERLIB_DIR is not set"
      sys.exit(1)
    if not os.path.exists(beakerlib_dir):
      print >> sys.stderr, "bstor: BEAKERLIB_DIR set but does not exist (%s)" % beakerlib_dir 
      sys.exit(1)

    st_dir = os.path.join(beakerlib_dir, Storage.SUBDIR)
    if not os.path.exists(st_dir):
      os.mkdir(st_dir)

    return st_dir

  def __obtain_file(self):
    fpath = os.path.join(self.__obtain_dir(), self.namespace)
    cp = ConfigParser.ConfigParser()
    if os.path.exists(fpath):
      cp.read(fpath)

    return cp

  def __save_file(self, parser):
    fpath = os.path.join(self.__obtain_dir(), self.namespace)
    cfile = open(fpath, 'w')
    parser.write(cfile)
    cfile.close()

  def get(self, key):
    parser = self.__obtain_file()
    try:
      retval = parser.get(self.section, key)
    except ConfigParser.NoSectionError:
      retval = None
    except ConfigParser.NoOptionError:
      retval = None\

    return retval

  def put(self, key, value):
    parser = self.__obtain_file()
    if not parser.has_section(self.section):
      parser.add_section(self.section)

    parser.set(self.section, key, value)
    self.__save_file(parser)

  def prune(self, key):
    parser = self.__obtain_file()
    if parser.has_section(self.section):
      parser.remove_option(self.section, key)
      self.__save_file(parser)

if __name__ == "__main__":
  DESCRIPTION = "Controlling "
  optparser = OptionParser(description=DESCRIPTION)
  optparser.add_option("--section", default="GENERIC", dest='section')
  optparser.add_option("--namespace", default="GENERIC", dest="namespace")

  (options, args) = optparser.parse_args()
  if len(args) < 2:
    print >> sys.stderr, "bstor: Needs at least two arguments (command, key)"
    sys.exit(1)

  command = args[0]
  key = args[1]

  storage = Storage(section=options.section, namespace=options.namespace)
  if command == "put":
    if len(args) != 3:
      print >> sys.stderr, "bstor: PUT needs exactly three arguments (command, key, value)"
      sys.exit(1)
    storage.put(key, value=args[2])
  elif command == "get":
    result = storage.get(key)
    if result is not None:
      print result
  elif command == "prune":
    storage.prune(key)
  else:
    print >> sys.stderr, "bstor: Unknown command (%s)" % command

