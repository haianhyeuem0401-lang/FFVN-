import argparse
import base64
import hashlib
import json
import re
import ssl
import time
import urllib.request
from pathlib import Path

import lief
from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding


FORBIDDEN_BINARY_MARKERS = (
    b"__PASTE_SIGNING_PUBLIC_KEY_HERE__",
    b"Suppressed integrity alert",
    b"Suppressed activation nag",
    b"hooks installed",
    b"research build",
    b"research source repository",
    b"[MCMFilza]",
    b"[WallpaperLab]",
    b"[Tweak]",
    b"BEGIN PRIVATE KEY",
    b"FFCACHE_SECRET=",
    b"ADMIN_TOKEN=",
)


def digest(value):
    return hashlib.sha256(bytes(value)).hexdigest()


def section_digest(binary, mutation=None):
    payload = bytearray()
    for section in binary.sections:
        content = bytearray(section.content)
        if content and mutation == section.name:
            content[len(content) // 2] ^= 0x01
        if content:
            payload.extend(content)
    return digest(payload)


def public_key_from_source(source_path):
    source = source_path.read_text(encoding="utf-8")
    match = re.search(
        r"static NSString \*const FFResponseSigningPublicKeyPEM\s*=\s*(.*?);",
        source,
        re.DOTALL,
    )
    if not match:
        raise RuntimeError("Client response-signing public key is missing")
    pieces = re.findall(r'@"((?:[^"\\]|\\.)*)"', match.group(1))
    pem = "".join(bytes(piece, "utf-8").decode("unicode_escape") for piece in pieces).encode()
    return serialization.load_pem_public_key(pem)


def signing_input(envelope, data=None, timestamp=None, nonce=None):
    canonical = json.dumps(
        envelope["data"] if data is None else data,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    ).replace("/", r"\/")
    return (
        f"{envelope['sig_ts'] if timestamp is None else timestamp}|"
        f"{envelope['sig_nonce'] if nonce is None else nonce}|{canonical}"
    ).encode("utf-8")


def verify_envelope(public_key, envelope, payload=None, timestamp=None, nonce=None, signature=None):
    public_key.verify(
        base64.b64decode(envelope["sig"] if signature is None else signature),
        signing_input(envelope, payload, timestamp, nonce),
        padding.PSS(mgf=padding.MGF1(hashes.SHA256()), salt_length=hashes.SHA256.digest_size),
        hashes.SHA256(),
    )


def expect_invalid(operation, label):
    try:
        operation()
    except (InvalidSignature, ValueError, KeyError):
        return
    raise RuntimeError(f"Tampered {label} was accepted")


def main():
    parser = argparse.ArgumentParser(description="Verify release binary/framework/API tamper rejection")
    parser.add_argument("build_directory")
    parser.add_argument("release_manifest")
    parser.add_argument("--api", default="https://SERVER-ADDRESS-REMOVED/api/v1/status")
    args = parser.parse_args()

    root = Path(__file__).resolve().parent
    build = Path(args.build_directory).resolve()
    manifest = json.loads(Path(args.release_manifest).read_text(encoding="utf-8"))["integrity"]
    app_path = build / "Payload" / "FFCacheManager.app" / "FFCacheManager"
    core_path = build / "Payload" / "FFCacheManager.app" / "Frameworks" / "CoreTelemetry.framework" / "CoreTelemetry"
    app_bytes = app_path.read_bytes()
    core_bytes = core_path.read_bytes()
    leaked = [value.decode("ascii") for value in FORBIDDEN_BINARY_MARKERS if value in app_bytes + core_bytes]
    if leaked:
        raise RuntimeError(f"Forbidden release markers remain: {leaked}")

    app = lief.MachO.parse(app_path)
    core = lief.MachO.parse(core_path)
    if app is None or len(app) != 1 or core is None or len(core) != 2:
        raise RuntimeError("Unexpected release Mach-O layout")
    app_binary = app.at(0)
    app_text = app_binary.get_section("__text")
    app_cstring = app_binary.get_section("__cstring")
    if app_text is None or digest(app_text.content) != manifest["app_text_sha256"]:
        raise RuntimeError("Original application code digest does not match its manifest")
    if app_cstring is None or digest(app_cstring.content) != manifest["app_cstring_sha256"]:
        raise RuntimeError("Original application cstring digest does not match its manifest")
    changed_text = bytearray(app_text.content)
    changed_text[len(changed_text) // 2] ^= 0x01
    if digest(changed_text) == manifest["app_text_sha256"]:
        raise RuntimeError("Application text mutation did not change the integrity digest")
    changed_cstring = bytearray(app_cstring.content)
    changed_cstring[len(changed_cstring) // 2] ^= 0x01
    if digest(changed_cstring) == manifest["app_cstring_sha256"]:
        raise RuntimeError("Application cstring mutation did not change the integrity digest")

    metadata = json.loads((build / "protected-core.json").read_text(encoding="utf-8"))["slices"]
    for index, (binary, expected) in enumerate(zip(core, metadata)):
        text = binary.get_section("__text")
        exports = binary.dyld_exports_trie
        if bytes(text.content[:4]) != bytes.fromhex("c0035fd6"):
            raise RuntimeError(f"Core constructor hooks remain active in slice {index}")
        if section_digest(binary) != expected["section_sha256"]:
            raise RuntimeError(f"Original core section digest mismatch in slice {index}")
        if section_digest(binary, "__cstring") == expected["section_sha256"]:
            raise RuntimeError(f"Core cstring mutation was accepted in slice {index}")
        changed_text = bytearray(text.content)
        changed_text[len(changed_text) // 2] ^= 0x01
        if digest(changed_text) == expected["text_sha256"]:
            raise RuntimeError(f"Core text mutation was accepted in slice {index}")
        changed_exports = bytearray(exports.content)
        changed_exports[len(changed_exports) // 2] ^= 0x01
        if digest(changed_exports) == expected["export_sha256"]:
            raise RuntimeError(f"Core export mutation was accepted in slice {index}")

    with urllib.request.urlopen(args.api, timeout=20, context=ssl._create_unverified_context()) as response:
        envelope = json.loads(response.read())
    if envelope.get("sig_alg") != "RSA-PSS-SHA256" or abs(time.time() - envelope.get("sig_ts", 0)) > 300:
        raise RuntimeError("Production response is unsigned or stale")
    public_key = public_key_from_source(root / "main.m")
    verify_envelope(public_key, envelope)

    altered_data = dict(envelope["data"])
    altered_data["service"] = str(altered_data.get("service", "")) + "-tampered"
    expect_invalid(lambda: verify_envelope(public_key, envelope, payload=altered_data), "API payload")
    expect_invalid(lambda: verify_envelope(public_key, envelope, nonce=envelope["sig_nonce"] + "00"), "API nonce")
    expect_invalid(lambda: verify_envelope(public_key, envelope, timestamp=envelope["sig_ts"] - 600), "API timestamp")
    signature = bytearray(base64.b64decode(envelope["sig"]))
    signature[0] ^= 0x01
    expect_invalid(
        lambda: verify_envelope(public_key, envelope, signature=base64.b64encode(signature)),
        "API signature",
    )
    expect_invalid(lambda: verify_envelope(public_key, {"data": envelope["data"]}), "unsigned API response")

    provisioning = build / "Payload" / "FFCacheManager.app" / "embedded.mobileprovision"
    signing_state = "DISTRIBUTION_PROFILE_PRESENT" if provisioning.is_file() else "SIGNING_PENDING"
    print(json.dumps({
        "status": "SECURITY_TAMPER_TEST_PASS",
        "main_text_mutation": "REJECTED",
        "main_cstring_mutation": "REJECTED",
        "core_text_mutation": "REJECTED",
        "core_cstring_mutation": "REJECTED",
        "core_export_mutation": "REJECTED",
        "api_payload_mutation": "REJECTED",
        "api_nonce_mutation": "REJECTED",
        "api_timestamp_mutation": "REJECTED",
        "api_signature_mutation": "REJECTED",
        "unsigned_api_response": "REJECTED",
        "signing": signing_state,
    }, indent=2))


if __name__ == "__main__":
    main()
