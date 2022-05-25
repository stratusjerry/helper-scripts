import base64
import json

file = "/path/to/twitch.json"
output_path = "/path/to/"
f = open(file)
# TODO: img type detection (animated gif); checksum image dedupe; multi file support

def write_file(prefix, img_obj_dict):
    counter = 0
    for img_obj in img_obj_dict:
        counter += 1
        img = list(img_obj.values())[2]
        outfile = f"{output_path}{counter}{prefix}.png"
        with open(outfile, "wb") as fh:
            fh.write(base64.urlsafe_b64decode(img))


data = json.load(f)
#streamer = list(data.keys())[0]
#comments = list(data.keys())[1]
#video = list(data.keys())[2]
emotes = list(data.values())[3]
thirdParty = list(emotes.values())[0]
firstParty = list(emotes.values())[1]

write_file("fp", firstParty)
write_file("tp", thirdParty)
