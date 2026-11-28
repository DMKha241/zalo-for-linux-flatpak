#!/usr/bin/env python3

import hashlib
import json
import os
import re
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

UPSTREAM_REPO = "VN-Linux-Family/zalo-for-linux"
UPSTREAM_URL = f"https://github.com/{UPSTREAM_REPO}"

FLATPAK_YML_PATH = Path("modules/zalo-for-linux.yml")
METAINFO_XML_PATH = Path("net.vietnamlinuxfamily.zalo_for_linux.metainfo.xml")

GITHUB_API_BASE = f"https://api.github.com/repos/{UPSTREAM_REPO}"

FILTERED_PREFIXES = ("ci", "chore", "merge", "test", "workflow", "documentation")

def should_filter_commit(message):
    message = message.lower()

    if any(keyword in message for keyword in FILTERED_PREFIXES):
        return True

    first_line = message.splitlines()[0].strip()
    prefix = first_line.split(":", 1)[0].strip()

    return bool(re.search(r"\bdocs?\b", prefix))

def github_api(endpoint):
    headers = {"User-Agent": "update-script", "Accept": "application/vnd.github+json"}
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(f"{GITHUB_API_BASE}/{endpoint}", headers=headers)
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())

def download_sha256_and_size(url):
    req = urllib.request.Request(url, headers={"User-Agent": "update-script"})
    h = hashlib.sha256()
    total_size = 0
    with urllib.request.urlopen(req) as resp:
        while True:
            chunk = resp.read(1 << 20)
            if not chunk:
                break
            total_size += len(chunk)
            h.update(chunk)
    return h.hexdigest(), total_size


class _NoRedirectHandler(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def get_latest_windows_version():
    req = urllib.request.Request(
        "https://zalo.me/download/zalo-pc?utm=90000",
        headers={
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/120.0.0.0 Safari/537.36"
            )
        },
    )
    opener = urllib.request.build_opener(_NoRedirectHandler)
    try:
        response = opener.open(req, timeout=30)
    except urllib.error.HTTPError as error:
        response = error

    try:
        if response.code != 302:
            raise RuntimeError(
                f"Unexpected Windows download response: HTTP {response.code}"
            )
        location = response.headers.get("Location", "")
    finally:
        response.close()

    match = re.search(r"(?:^|/)ZaloSetup-([0-9.]+)\.exe(?:[?#].*)?$", location)
    if not match:
        raise RuntimeError(f"Could not parse Windows version from redirect: {location}")
    return match.group(1)


def update_extra_data_source(yml_text, platform, version):
    if platform == "mac":
        filename = f"ZaloSetup-universal-{version}.dmg"
        source_path = "/mac/"
        extension = ".dmg"
    elif platform == "win":
        filename = f"ZaloSetup-{version}.exe"
        source_path = "/win/"
        extension = ".exe"
    else:
        raise ValueError(f"Unsupported Zalo source: {platform}")

    url_pattern = re.compile(
        r"^(?P<prefix>\s*url:\s*)(?P<url>https?://\S+)",
        re.MULTILINE,
    )
    for match in url_pattern.finditer(yml_text):
        url = match.group("url")
        if source_path not in url or not url.endswith(extension):
            continue

        new_url = url.rsplit("/", 1)[0] + "/" + filename
        new_hash, new_size = download_sha256_and_size(new_url)

        block_start = match.start()
        next_source = re.search(r"^  - type:", yml_text[match.end():], re.MULTILINE)
        block_end = match.end() + next_source.start() if next_source else len(yml_text)
        block = yml_text[block_start:block_end]
        block = re.sub(
            r"^(?P<prefix>\s*url:\s*)https?://\S+",
            lambda item: item.group("prefix") + new_url,
            block,
            count=1,
            flags=re.MULTILINE,
        )
        for field, value in (
            ("sha256", new_hash),
            ("size", str(new_size)),
            ("filename", filename),
        ):
            pattern = re.compile(
                rf"^(?P<prefix>\s*{field}:\s*).*$",
                re.MULTILINE,
            )
            block, count = pattern.subn(
                lambda item, value=value: item.group("prefix") + value,
                block,
                count=1,
            )
            if count != 1:
                raise RuntimeError(f"Missing {field} in {platform} extra-data source")

        return yml_text[:block_start] + block + yml_text[block_end:]

    raise RuntimeError(f"Could not find Zalo {platform} extra-data source")

def set_output(key, value):
    gh_output = os.environ.get("GITHUB_OUTPUT")
    if not gh_output:
        print(f"  {key}={value}")
        return
    with open(gh_output, "a") as f:
        if "\n" in str(value):
            f.write(f"{key}<<EOF\n{value}\nEOF\n")
        else:
            f.write(f"{key}={value}\n")

def main():
    yml_text = FLATPAK_YML_PATH.read_text()

    current_commit_match = re.search(r"commit:\s*([0-9a-f]{7,40})", yml_text)
    mac_version_match = re.search(
        r"ZaloSetup-universal-([0-9.]+)\.dmg", yml_text
    )
    windows_version_match = re.search(
        r"url:\s*https?://[^\s]*/win/ZaloSetup-([0-9.]+)\.exe", yml_text
    )
    if not current_commit_match or not mac_version_match or not windows_version_match:
        raise RuntimeError("Could not determine current Zalo source versions")

    current_commit = current_commit_match.group(1)
    current_mac_version = mac_version_match.group(1)
    current_windows_version = windows_version_match.group(1)

    latest_release = github_api("releases/latest")
    upstream_version = latest_release["tag_name"].lstrip("v")
    try:
        upstream_windows_version = get_latest_windows_version()
    except Exception as error:
        print(f"Warning: Could not check Windows source: {error}")
        upstream_windows_version = current_windows_version

    upstream_commit = github_api("commits?per_page=1")[0]["sha"]

    version_changed = upstream_version != current_mac_version
    windows_version_changed = upstream_windows_version != current_windows_version
    commit_changed = upstream_commit != current_commit

    if not version_changed and not windows_version_changed and not commit_changed:
        print("Nothing to update.")
        set_output("has_update", "false")
        sys.exit(0)

    if commit_changed:
        yml_text = yml_text.replace(current_commit, upstream_commit, 1)

    if version_changed:
        print(f"Updating macOS source to {upstream_version}...")
        yml_text = update_extra_data_source(yml_text, "mac", upstream_version)

    if windows_version_changed:
        print(f"Updating Windows source to {upstream_windows_version}...")
        yml_text = update_extra_data_source(
            yml_text, "win", upstream_windows_version
        )

    FLATPAK_YML_PATH.write_text(yml_text)

    commit_messages = []
    if commit_changed:
        comparison = github_api(f"compare/{current_commit}...{upstream_commit}")
        for entry in comparison.get("commits", []):
            message = entry["commit"]["message"]
            first_line = message.splitlines()[0].strip()

            if not first_line or should_filter_commit(message):
                continue

            commit_messages.append(first_line)

    meta_text = METAINFO_XML_PATH.read_text()

    now = datetime.now(timezone.utc)
    release_tag = upstream_version if version_changed else current_mac_version
    release_version = f"{release_tag}.{now.strftime('%y%m%d%H%M%S')}"
    release_date = now.strftime("%Y-%m-%d")

    description_lines = []
    if version_changed:
        description_lines.append(f"<p>Update macOS source to {upstream_version}</p>")
    if windows_version_changed:
        description_lines.append(
            f"<p>Update Windows source to {upstream_windows_version}</p>"
        )
    if commit_messages:
        description_lines.append("<ul>")
        for msg in commit_messages:
            escaped = msg.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
            description_lines.append(f"    <li>{escaped}</li>")
        description_lines.append("</ul>")

    description_body = "\n        ".join(description_lines) if description_lines else "<p>Update</p>"

    release_entry = (
        f'    <release version="{release_version}" date="{release_date}">\n'
        f"      <description>\n"
        f"        {description_body}\n"
        f"      </description>\n"
        f"    </release>"
    )

    meta_text = meta_text.replace("<releases>", f"<releases>\n{release_entry}", 1)
    METAINFO_XML_PATH.write_text(meta_text)

    set_output("has_update", "true")
    set_output("commit_changed", str(commit_changed).lower())
    set_output("version_changed", str(version_changed).lower())
    set_output("windows_version_changed", str(windows_version_changed).lower())
    set_output("release_version", release_version)
    set_output("upstream_version", upstream_version)
    set_output("current_windows_version", current_windows_version)
    set_output("upstream_windows_version", upstream_windows_version)
    set_output("upstream_commit", upstream_commit)
    set_output("current_commit", current_commit)
    if commit_messages:
        set_output("commit_messages", "\n".join(commit_messages))

    print(
        f"Updated: commit={upstream_commit[:10]}… "
        f"macOS={upstream_version} Windows={upstream_windows_version} "
        f"release={release_version}"
    )

if __name__ == "__main__":
    main()
