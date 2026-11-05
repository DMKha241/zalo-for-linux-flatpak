#!/usr/bin/env python3

import hashlib
import json
import os
import re
import sys
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

def download_sha256(url):
    req = urllib.request.Request(url, headers={"User-Agent": "update-script"})
    h = hashlib.sha256()
    with urllib.request.urlopen(req) as resp:
        while True:
            chunk = resp.read(1 << 20)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()

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

    current_commit = re.search(r"commit:\s*([0-9a-f]{7,40})", yml_text).group(1)
    current_version = re.search(r"ZaloSetup.*?-(\d+\.\d+\.\d+)\.(exe|dmg)", yml_text).group(1)

    latest_release = github_api("releases/latest")
    upstream_version = latest_release["tag_name"].lstrip("v")

    upstream_commit = github_api("commits?per_page=1")[0]["sha"]

    version_changed = upstream_version != current_version
    commit_changed = upstream_commit != current_commit

    if not version_changed and not commit_changed:
        print("Nothing to update.")
        set_output("has_update", "false")
        sys.exit(0)

    if commit_changed:
        yml_text = yml_text.replace(current_commit, upstream_commit, 1)

    if version_changed:
        yml_lines = yml_text.splitlines(keepends=True)
        updated_lines = []
        for line in yml_lines:
            if re.search(r"ZaloSetup.*\.(exe|dmg)", line) and current_version in line:
                line = line.replace(current_version, upstream_version)
            updated_lines.append(line)
        yml_text = "".join(updated_lines)

        for pattern in [r"(ZaloSetup-universal-[\d.]+\.dmg)", r"(ZaloSetup-[\d.]+\.exe)"]:
            match = re.search(pattern, yml_text)
            if not match:
                continue
            filename = match.group(1)
            url_match = re.search(rf"url:\s*(https?://\S*{re.escape(filename)})", yml_text)
            if not url_match:
                continue
            download_url = url_match.group(1)
            print(f"Downloading {filename} and calculating SHA256...")
            new_hash = download_sha256(download_url)
            lines = yml_text.splitlines(keepends=True)
            result = []
            found_url = False
            for line in lines:
                if filename in line and "url:" in line:
                    found_url = True
                    result.append(line)
                    continue
                if found_url and "sha256:" in line:
                    line = re.sub(r"[0-9a-f]{64}", new_hash, line)
                    found_url = False
                else:
                    found_url = False
                result.append(line)
            yml_text = "".join(result)

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
    release_tag = upstream_version if version_changed else current_version
    release_version = f"{release_tag}.{now.strftime('%y%m%d%H%M%S')}"
    release_date = now.strftime("%Y-%m-%d")

    description_lines = []
    if version_changed:
        description_lines.append(f"<p>Update to {upstream_version}</p>")
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
    set_output("release_version", release_version)
    set_output("upstream_version", upstream_version)
    set_output("upstream_commit", upstream_commit)
    set_output("current_commit", current_commit)
    if commit_messages:
        set_output("commit_messages", "\n".join(commit_messages))

    print(f"Updated: commit={upstream_commit[:10]}… version={release_tag} release={release_version}")

if __name__ == "__main__":
    main()
