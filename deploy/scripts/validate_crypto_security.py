import importlib.metadata
import re
import shutil
import ssl
import subprocess


MIN_CRYPTOGRAPHY = (46, 0, 7)
MAX_CRYPTOGRAPHY_EXCLUSIVE = (47, 0, 0)
VULNERABLE_OPENSSL_RANGES = (
    ((3, 0, 0), (3, 0, 20)),
    ((3, 3, 0), (3, 3, 7)),
    ((3, 4, 0), (3, 4, 5)),
    ((3, 5, 0), (3, 5, 6)),
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
                "CVE-2026-31789 affected ranges"
            )


cryptography_version = importlib.metadata.version("cryptography")
if _version_tuple(cryptography_version) < MIN_CRYPTOGRAPHY:
    raise AssertionError(
        f"cryptography {cryptography_version} is vulnerable to CVE-2026-39892; "
        "requires cryptography>=46.0.7"
    )
if _version_tuple(cryptography_version) >= MAX_CRYPTOGRAPHY_EXCLUSIVE:
    raise AssertionError(
        f"cryptography {cryptography_version} exceeds the mlflow-compatible range; "
        "requires cryptography>=46.0.7,<47.0.0"
    )

_assert_not_vulnerable_openssl("python ssl", ssl.OPENSSL_VERSION)

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

print(f"crypto security validation ok: cryptography={cryptography_version}; {ssl.OPENSSL_VERSION}")
