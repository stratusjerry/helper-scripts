import os
import time
import requests
from bs4 import BeautifulSoup

dl_dir = "./output/"  # Update this to your desired path, must end with slash

if not os.path.exists(dl_dir):
    os.makedirs(dl_dir, exist_ok=True)


index_file = "index.txt"
expected_file_name = "vscode-server-linux-x64.tar.gz"
html_tag_url = "https://github.com/microsoft/vscode/releases/tag/"
sleep_time = 1
debug = True

headers = {
    "Accept": "application/vnd.github.v3+json",
    "User-Agent": "python-script"
}

def write_if_debug(message):
    if debug:
        print(message)

def write_failure(message):
    print(f"\033[91m{message}\033[0m")  # Red text
    input("Press Enter to continue...")

# Get releases from GitHub API
releases = requests.get(
    "https://api.github.com/repos/microsoft/vscode/releases",
    headers=headers
).json()

tag_array = [release["tag_name"] for release in releases]
vscode_vers = []
ver_commit_hash = {}

for tag_item in tag_array:
    html_url = html_tag_url + tag_item
    write_if_debug(f"Checking Tag: {tag_item}  URL: {html_url}")
    resp = requests.get(html_url, headers=headers)
    if resp.status_code != 200:
        write_failure(f"Failed to fetch {html_url}")
        continue
    # Find commit SHA in HTML
    soup = BeautifulSoup(resp.text, 'html.parser')
    allLinks = soup.find_all('a', href=True)
    #matches = [a['href'].split('/')[-1] for a in allLinks if '/microsoft/vscode/commit/' in a['href']]
    matches = []
    for a in allLinks:
        if a.has_attr('href'):
            if '/microsoft/vscode/commit/' in a['href']:
                # Turn '/microsoft/vscode/commit/b1c0a14de1414fcdaa400695b4db1c0799bc3124' into 'b1c0a14de1414fcdaa400695b4db1c0799bc3124'
                matches.append(a['href'].split('/')[-1])
                #matches = [a['href'].split('/')[-1]
                print(a['href'])
    if len(matches) == 0:
        write_failure("  Failed to find commit link")
        continue
    elif len(matches) > 1:
        write_failure("  Found multiple commit links")
    tag_sha = matches[0]
    print(f"Tag: {tag_item} CommitID: {tag_sha}")
    vscode_vers.append(tag_sha)
    ver_commit_hash[tag_item] = tag_sha
    time.sleep(sleep_time)

dl_processed = 0
dl_count = 0

for vscode_ver in vscode_vers:
    dl_processed += 1
    ver_path = os.path.join(dl_dir, vscode_ver)
    file_path = os.path.join(ver_path, expected_file_name)
    weblink = f"https://update.code.visualstudio.com/commit:{vscode_ver}/server-linux-x64/stable"
    if not os.path.exists(ver_path):
        write_if_debug(f"Creating directory: {ver_path}")
        os.makedirs(ver_path, exist_ok=True)
    if not os.path.exists(file_path):
        dl_count += 1
        print(f"File doesn't exist, downloading {dl_processed} of {len(vscode_vers)} to filepath: {file_path}")
        dl_file = requests.get(weblink, headers=headers, stream=True)
        if dl_file.status_code != 200:
            write_failure(f"Got an error downloading {weblink}")
            continue
        content_disp = dl_file.headers.get("Content-Disposition")
        # TESTING
        from email.message import Message # This is a workaround to get the filename from Content-Disposition
        msg = Message()
        msg['Content-Disposition'] = content_disp
        file_name = msg.get_filename()
        if file_name != expected_file_name:
            write_failure(f"Filename: {file_name} doesn't equal download file name: {expected_file_name}")
        full_file_path = os.path.join(ver_path, file_name)
        # Below hangs
        with open(full_file_path, "wb") as f:
            for chunk in dl_file.iter_content(chunk_size=8192):
                f.write(chunk)
                #if chunk:
                #    f.write(chunk)
    if debug:
        input("Press Enter to continue...")
    time.sleep(sleep_time)

index_file_path = os.path.join(dl_dir, index_file)
with open(index_file_path, "w", encoding="utf-8") as f:
    for tag, sha in ver_commit_hash.items():
        f.write(f"{tag} = {sha}\n")
