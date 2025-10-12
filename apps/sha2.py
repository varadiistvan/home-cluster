#!/usr/bin/env python3
import sys, json, base64, hashlib

def main():
    data = json.load(sys.stdin)
    plain = data["plain"]                  # expected "username:password"
    salt = data["salt"].encode("utf-8")
    its = int(data.get("iterations") or 424242)

    bplain = plain.encode("utf-8")
    ret = b"\n"
    for _ in range(its):
        ret = hashlib.sha512(salt + bplain + ret).digest()

    out = "+" + base64.urlsafe_b64encode(ret[:24]).decode("utf-8")
    json.dump({"hash": out}, sys.stdout)

if __name__ == "__main__":
    main()
