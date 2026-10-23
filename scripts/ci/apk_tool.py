#!/usr/bin/env python3
"""Outil CI pour les APK : lecture du manifeste binaire, contrôles d'installabilité, réparation.

Usage :
  apk_tool.py info   APK
  apk_tool.py check  APK [--package ID] [--min-version-code N] [--expect-admob] [--allow-duplicate-authorities]
  apk_tool.py fix-authorities APK        (build sans Gradle : rend uniques les autorités de « provider », puis réaligne et re-signe)

Pourquoi : l'export Godot 4.7.2 SANS Gradle réécrit l'attribut `authorities` de TOUS les <provider> du modèle en
« <package>.fileprovider » (platform/android/export/export_plugin.cpp). Le modèle en contient deux (FileProvider et
androidx.startup.InitializationProvider) : l'APK produit déclare donc deux fournisseurs de contenu avec la même autorité,
un manifeste invalide pour Android. `check` détecte ce défaut ; `fix-authorities` le corrige (autorité unique, même
longueur, donc sans toucher aux tailles de l'APK).

Sans dépendance externe (bibliothèque standard). `check` et `fix-authorities` utilisent `apksigner`/`zipalign` du SDK Android
(ANDROID_SDK_ROOT) ; la signature utilise GODOT_ANDROID_KEYSTORE_DEBUG_PATH / _USER / _PASSWORD.
"""
import argparse
import glob
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import zipfile

ADMOB_TEST_APP_ID = "ca-app-pub-3940256099942544~3347511713"
ADMOB_DEX_MARKERS = (b"com/poingstudios/godot/admob", b"com/google/android/libraries/ads/mobile/sdk")

CHUNK_STRING_POOL = 0x0001
CHUNK_START_ELEMENT = 0x0102
NO_INDEX = 0xFFFFFFFF
UTF8_FLAG = 0x100


class Manifest:
    """Lecteur minimal du XML binaire d'Android (AXML) : table de chaînes et éléments avec leurs attributs."""

    def __init__(self, data: bytes):
        self.data = bytearray(data)
        magic, _header, size = struct.unpack_from("<HHI", data, 0)
        if magic != 0x0003:
            raise ValueError("AndroidManifest.xml n'est pas un XML binaire Android")
        self.pool_offset = 8
        (kind, header, _size, count, _styles, self.flags, strings_start, _styles_start) = struct.unpack_from("<HHIIIIII", data, self.pool_offset)
        if kind != CHUNK_STRING_POOL:
            raise ValueError("table de chaînes introuvable")
        self.pool_header = header
        self.strings_base = self.pool_offset + strings_start
        self.offsets = list(struct.unpack_from("<%dI" % count, data, self.pool_offset + header))
        self.strings = [self._read_string(self.strings_base + o) for o in self.offsets]
        self.elements = self._read_elements()

    # -- chaînes
    def _read_string(self, pos: int) -> str:
        d = self.data
        if self.flags & UTF8_FLAG:
            n = d[pos]
            pos += 1
            if n & 0x80:
                pos += 1
            nbytes = d[pos]
            pos += 1
            if nbytes & 0x80:
                nbytes = ((nbytes & 0x7F) << 8) | d[pos]
                pos += 1
            return bytes(d[pos:pos + nbytes]).decode("utf-8", "replace")
        n = struct.unpack_from("<H", d, pos)[0]
        pos += 2
        if n & 0x8000:
            n = ((n & 0x7FFF) << 16) | struct.unpack_from("<H", d, pos)[0]
            pos += 2
        return bytes(d[pos:pos + 2 * n]).decode("utf-16le", "replace")

    def replace_string_same_length(self, index: int, new_text: str) -> None:
        """Remplace une chaîne de la table par une chaîne de MÊME longueur (aucun décalage dans le fichier)."""
        old = self.strings[index]
        if len(new_text) != len(old):
            raise ValueError("la nouvelle chaîne doit avoir la même longueur (%d != %d)" % (len(new_text), len(old)))
        if self.flags & UTF8_FLAG:
            raise ValueError("table UTF-8 : réparation non prévue (le modèle Godot utilise UTF-16)")
        pos = self.strings_base + self.offsets[index] + 2
        encoded = new_text.encode("utf-16le")
        self.data[pos:pos + len(encoded)] = encoded
        self.strings[index] = new_text

    # -- éléments
    def _read_elements(self):
        d = self.data
        pos = self.pool_offset + struct.unpack_from("<I", d, self.pool_offset + 4)[0]
        elements = []
        while pos + 8 <= len(d):
            kind, header, size = struct.unpack_from("<HHI", d, pos)
            if size < 8:
                break
            if kind == CHUNK_START_ELEMENT:
                name_idx = struct.unpack_from("<I", d, pos + 20)[0]
                attr_start, attr_size, attr_count = struct.unpack_from("<HHH", d, pos + 24)
                attrs = {}
                base = pos + 16 + attr_start
                for i in range(attr_count):
                    a = base + i * attr_size
                    _ns, a_name, raw, _vsize, _res, dtype, value = struct.unpack_from("<IIIHBBI", d, a)
                    attrs[self.strings[a_name]] = {"raw": raw, "type": dtype, "data": value}
                elements.append({"name": self.strings[name_idx], "attrs": attrs})
            pos += size
        return elements

    def value(self, attr: dict):
        if attr["type"] == 0x03:
            return self.strings[attr["data"]]
        if attr["type"] == 0x12:
            return attr["data"] != 0
        if attr["type"] in (0x10, 0x11):
            return attr["data"]
        if attr["raw"] != NO_INDEX:
            return self.strings[attr["raw"]]
        return attr["data"]

    def find(self, tag: str):
        return [e for e in self.elements if e["name"] == tag]

    def attr(self, element: dict, name: str, default=None):
        a = element["attrs"].get(name)
        return default if a is None else self.value(a)

    def summary(self) -> dict:
        manifest = self.find("manifest")[0]
        uses_sdk = (self.find("uses-sdk") or [{"attrs": {}}])[0]
        providers = []
        for p in self.find("provider"):
            a = p["attrs"].get("authorities")
            providers.append({
                "name": self.attr(p, "name"),
                "authority": self.value(a) if a else None,
                "authority_index": a["data"] if a and a["type"] == 0x03 else None,
            })
        metas = {self.attr(m, "name"): self.attr(m, "value") for m in self.find("meta-data")}
        return {
            "package": self.attr(manifest, "package"),
            "versionCode": self.attr(manifest, "versionCode"),
            "versionName": self.attr(manifest, "versionName"),
            "minSdk": self.attr(uses_sdk, "minSdkVersion"),
            "targetSdk": self.attr(uses_sdk, "targetSdkVersion"),
            "permissions": sorted(str(self.attr(p, "name")) for p in self.find("uses-permission")),
            "providers": providers,
            "meta": metas,
        }


def read_manifest(apk: str) -> Manifest:
    with zipfile.ZipFile(apk) as z:
        return Manifest(z.read("AndroidManifest.xml"))


def duplicate_authorities(summary: dict):
    seen, duplicates = {}, []
    for p in summary["providers"]:
        if not p["authority"]:
            continue
        for authority in str(p["authority"]).split(";"):
            if authority in seen:
                duplicates.append((authority, seen[authority], p["name"]))
            else:
                seen[authority] = p["name"]
    return duplicates


# ------------------------------------------------------------------ outils du SDK
def sdk_tool(name: str):
    root = os.environ.get("ANDROID_SDK_ROOT") or os.environ.get("ANDROID_HOME") or ""
    candidates = sorted(glob.glob(os.path.join(root, "build-tools", "*", name)), reverse=True)
    if candidates:
        return candidates[0]
    return shutil.which(name)


def run(cmd, **kwargs):
    return subprocess.run(cmd, check=False, capture_output=True, text=True, **kwargs)


def verify_signature(apk: str):
    """Renvoie (ok, message). L'APK doit porter une signature v2 ou v3 valide (Android refuse un APK non signé)."""
    apksigner = sdk_tool("apksigner")
    if apksigner is None:
        return False, "apksigner introuvable (ANDROID_SDK_ROOT)"
    result = run([apksigner, "verify", "--verbose", "--print-certs", apk])
    out = result.stdout + result.stderr
    if result.returncode != 0:
        return False, "signature invalide :\n" + out
    schemes = [line.strip() for line in out.splitlines() if line.startswith("Verified using v") and line.rstrip().endswith("true")]
    if not schemes:
        return False, "aucune signature v1/v2/v3 valide :\n" + out
    cert = [line.strip() for line in out.splitlines() if "certificate SHA-256" in line]
    return True, "; ".join(s.replace("Verified using ", "") for s in schemes) + " | " + (cert[0] if cert else "")


def dex_mentions_admob(apk: str) -> bool:
    with zipfile.ZipFile(apk) as z:
        for name in z.namelist():
            if name.startswith("classes") and name.endswith(".dex"):
                blob = z.read(name)
                if any(marker in blob for marker in ADMOB_DEX_MARKERS):
                    return True
    return False


# ------------------------------------------------------------------ commandes
def cmd_info(args) -> int:
    s = read_manifest(args.apk).summary()
    print("package      :", s["package"])
    print("version      : %s (code %s)" % (s["versionName"], s["versionCode"]))
    print("minSdk/target: %s / %s" % (s["minSdk"], s["targetSdk"]))
    print("permissions  :", ", ".join(p.replace("android.permission.", "") for p in s["permissions"]))
    for p in s["providers"]:
        print("provider     : %s  authorities=%s" % (p["name"], p["authority"]))
    for key in ("com.google.android.gms.ads.APPLICATION_ID",):
        if key in s["meta"]:
            print("meta         : %s = %s" % (key, s["meta"][key]))
    return 0


def cmd_check(args) -> int:
    errors, notes = [], []
    if not zipfile.is_zipfile(args.apk):
        print("ERREUR : %s n'est pas une archive APK valide" % args.apk)
        return 1
    s = read_manifest(args.apk).summary()
    notes.append("package %s, version %s (code %s), minSdk %s, targetSdk %s" % (s["package"], s["versionName"], s["versionCode"], s["minSdk"], s["targetSdk"]))
    if args.package and s["package"] != args.package:
        errors.append("package %r au lieu de %r" % (s["package"], args.package))
    if args.min_version_code is not None and (s["versionCode"] or 0) < args.min_version_code:
        errors.append("versionCode %s < %s attendu" % (s["versionCode"], args.min_version_code))
    if not args.allow_duplicate_authorities:
        for authority, first, second in duplicate_authorities(s):
            errors.append("autorité de provider en double « %s » (%s et %s) : Android refusera ou cassera l'application" % (authority, first, second))
    ok, message = verify_signature(args.apk)
    (notes if ok else errors).append("signature : " + message)
    if args.expect_admob:
        app_id = s["meta"].get("com.google.android.gms.ads.APPLICATION_ID")
        if app_id != ADMOB_TEST_APP_ID:
            errors.append("identifiant d'application AdMob %r au lieu de l'identifiant de TEST de Google %r" % (app_id, ADMOB_TEST_APP_ID))
        else:
            notes.append("AdMob : identifiant d'application de test présent")
        if not dex_mentions_admob(args.apk):
            errors.append("le SDK / plugin AdMob n'est pas dans le code (classes*.dex) : ce n'est pas un build Gradle avec le plugin")
        else:
            notes.append("AdMob : SDK Google et plugin présents dans le code de l'APK")
        for permission in ("android.permission.INTERNET", "android.permission.ACCESS_NETWORK_STATE"):
            if permission not in s["permissions"]:
                errors.append("permission manquante : " + permission)
    for note in notes:
        print("OK     :", note)
    for error in errors:
        print("ERREUR :", error)
    return 1 if errors else 0


def unique_authority(original: str, taken: set) -> str:
    """Autorité unique de MÊME longueur que l'originale (suffixe « .androidstart », puis numérotée si besoin)."""
    suffix = ".fileprovider"
    prefix = original[: -len(suffix)] if original.endswith(suffix) else original[:-13]
    for candidate_suffix in [".androidstart"] + [".androidstar%d" % n for n in range(2, 10)]:
        candidate = prefix + candidate_suffix
        if len(candidate) == len(original) and candidate not in taken:
            return candidate
    raise ValueError("impossible de fabriquer une autorité unique pour " + original)


def cmd_fix_authorities(args) -> int:
    manifest = read_manifest(args.apk)
    summary = manifest.summary()
    if not duplicate_authorities(summary):
        print("Aucune autorité en double : rien à réparer.")
        return 0
    seen = set()
    for p in summary["providers"]:
        if p["authority"] is None:
            continue
        if p["authority"] in seen:
            if p["authority_index"] is None:
                print("ERREUR : autorité en double non réparable (valeur non textuelle)")
                return 1
            new = unique_authority(p["authority"], seen | {q["authority"] for q in summary["providers"]})
            print("provider %s : autorité %s -> %s" % (p["name"], p["authority"], new))
            manifest.replace_string_same_length(p["authority_index"], new)
            seen.add(new)
        else:
            seen.add(p["authority"])
    work = tempfile.mkdtemp(prefix="apkfix-")
    rezipped = os.path.join(work, "rezipped.apk")
    aligned = os.path.join(work, "aligned.apk")
    with zipfile.ZipFile(args.apk) as zin, zipfile.ZipFile(rezipped, "w") as zout:
        for info in zin.infolist():
            if info.filename.startswith("META-INF/") and info.filename.upper().endswith((".SF", ".RSA", ".DSA", ".EC", ".MF")):
                continue  # l'ancienne signature n'est plus valable
            data = bytes(manifest.data) if info.filename == "AndroidManifest.xml" else zin.read(info.filename)
            clone = zipfile.ZipInfo(info.filename, date_time=info.date_time)
            clone.compress_type = info.compress_type
            clone.external_attr = info.external_attr
            zout.writestr(clone, data)
    zipalign = sdk_tool("zipalign")
    if zipalign is None:
        print("ERREUR : zipalign introuvable")
        return 1
    result = run([zipalign, "-f", "-P", "16", "4", rezipped, aligned])
    if result.returncode != 0:  # anciennes build-tools : pas d'option -P
        result = run([zipalign, "-f", "-p", "4", rezipped, aligned])
    if result.returncode != 0:
        print("ERREUR zipalign :", result.stdout + result.stderr)
        return 1
    apksigner = sdk_tool("apksigner")
    keystore = os.environ.get("GODOT_ANDROID_KEYSTORE_DEBUG_PATH")
    if apksigner is None or not keystore:
        print("ERREUR : apksigner ou clé de signature (GODOT_ANDROID_KEYSTORE_DEBUG_PATH) introuvable")
        return 1
    result = run([
        apksigner, "sign", "--ks", keystore,
        "--ks-pass", "pass:" + os.environ.get("GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD", "android"),
        "--ks-key-alias", os.environ.get("GODOT_ANDROID_KEYSTORE_DEBUG_USER", "androiddebugkey"),
        "--out", args.apk, aligned,
    ])
    shutil.rmtree(work, ignore_errors=True)
    if result.returncode != 0:
        print("ERREUR apksigner :", result.stdout + result.stderr)
        return 1
    idsig = args.apk + ".idsig"
    if os.path.exists(idsig):
        os.remove(idsig)
    print("APK réparé, réaligné et re-signé :", args.apk)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    info = sub.add_parser("info")
    info.add_argument("apk")
    info.set_defaults(func=cmd_info)
    check = sub.add_parser("check")
    check.add_argument("apk")
    check.add_argument("--package")
    check.add_argument("--min-version-code", type=int)
    check.add_argument("--expect-admob", action="store_true")
    check.add_argument("--allow-duplicate-authorities", action="store_true")
    check.set_defaults(func=cmd_check)
    fix = sub.add_parser("fix-authorities")
    fix.add_argument("apk")
    fix.set_defaults(func=cmd_fix_authorities)
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
