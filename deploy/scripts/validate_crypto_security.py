import importlib.metadata
import re
import shutil
import ssl
import subprocess

from cryptography.hazmat.backends.openssl.backend import backend


MIN_CRYPTOGRAPHY = (48, 0, 1)
MAX_CRYPTOGRAPHY_EXCLUSIVE = (49, 0, 0)
VULNERABLE_OPENSSL_RANGES = (
    ((3, 0, 0), (3, 0, 21)),
    ((3, 3, 0), (3, 3, 7)),
    ((3, 4, 0), (3, 4, 6)),
    ((3, 5, 0), (3, 5, 7)),
    ((3, 6, 0), (3, 6, 3)),
    ((4, 0, 0), (4, 0, 1)),
)


def _version_tuple(value: str) -> tuple[int, int, int]:
    parts = [int(part) for part in re.findall(r"\d+", value)[:3]]
    while len(parts) < 3:
        parts.append(0)
    return tuple(parts)


def _assert_not_vulnerable_openssl(label: str, version_text: str) -> None:
    version = _version_tuple(version_text)
    for lower, upper in VULNERABLE_OPENSSL_RANGES:
        if lower <= version < upper:
            raise AssertionError(
                f"{label} uses OpenSSL {version_text}; requires a version outside "
                "the CVE-2026-34182 affected ranges"
            )


cryptography_version = importlib.metadata.version("cryptography")
if _version_tuple(cryptography_version) < MIN_CRYPTOGRAPHY:
    raise AssertionError(
        f"cryptography {cryptography_version} has a known fixable high-severity advisory; "
        "requires cryptography>=48.0.1"
    )
if _version_tuple(cryptography_version) >= MAX_CRYPTOGRAPHY_EXCLUSIVE:
    raise AssertionError(
        f"cryptography {cryptography_version} exceeds the mlflow-compatible range; "
        "requires cryptography>=48.0.1,<49.0.0"
    )

_assert_not_vulnerable_openssl("python ssl", ssl.OPENSSL_VERSION)
_assert_not_vulnerable_openssl("cryptography backend", backend.openssl_version_text())

openssl = shutil.which("openssl")
if openssl:
    result = subprocess.run(
        [openssl, "version"],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    _assert_not_vulnerable_openssl("openssl CLI", result.stdout.strip())

print(
    "crypto security validation ok: "
    f"cryptography={cryptography_version}; "
    f"backend={backend.openssl_version_text()}; "
    f"stdlib={ssl.OPENSSL_VERSION}"
)
