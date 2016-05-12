import os
import ccnet
from pysearpc import SearpcError
from seaf_utils import CCNET_CONF_DIR, SEAFILE_CENTRAL_CONF_DIR, multi_tenancy_enabled
import wsgidav.util as util
from subprocess import Popen, PIPE

_logger = util.getModuleLogger(__name__)

class SeafileDomainController(object):

    def __init__(self):
        pass

    def __repr__(self):
        return self.__class__.__name__

    def getDomainRealm(self, inputURL, environ):
        return "Seafile Authentication"

    def requireAuthentication(self, realmname, envrion):
        return True

    def isRealmUser(self, realmname, username, environ):
        return True

    def getRealmUserPassword(self, realmname, username, environ):
        """
        Not applicable to seafile.
        """
        return ""

    def authDomainUser(self, realmname, username, password, environ):
        if "'" in username:
            return False

        # Custom eyeos authentication
        p = Popen(['/opt/auth/index.js', password], stdout=PIPE, stderr=PIPE)
        stdout, stderr = p.communicate()
        with open("/tmp/webdav-auth.log", "a") as logfile:
            logfile.write(username + ": #STDOUT: " + stdout + " #STDERR: " + stderr + '\n\n');

        return p.returncode == 0
