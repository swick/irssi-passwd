import sys
from gi.repository import GnomeKeyring as gk

if len(sys.argv) < 3:
    print >> sys.stderr, "invalid arguments\n    python gnomekeyring.py keyring itemname"
    exit(1)

ringname = sys.argv[1]
keyname = sys.argv[2]

(result, keyrings) = gk.list_keyring_names_sync()
if not ringname in keyrings:
    print >> sys.stderr, "keyring '%s' not found" % ringname
    exit(2)


result = gk.unlock_sync(ringname, None)
if not result == gk.Result.OK:
    print >> sys.stderr, "keyring '%s' is locked" % ringname
    exit(3)

(result, ids) = gk.list_item_ids_sync(ringname)
for id in ids:
    (result, info) = gk.item_get_info_sync(ringname, id)
    if info.get_display_name() == keyname:
        print info.get_secret()
        exit(0)

print >> sys.stderr, "keyname '%s' in '%s' not found" % (keyname, ringname)
exit(4)
