import codecs
import base64
import collections

start_string_char = 0 # Start of blob, can be offset
chars_to_count = 2 # Number of characters to use when looking for matches
common_limit = 10 # Limit output of most common characters matched
blob = '''A_Really_Big_Blob_Of_Text_here'''
# Attempt to decode blob
#blob_b64 = codecs.decode(blob, "hex")
#print(base64.b64decode(blob))
# Attempt to find bad data in string
#from collections import defaultdict
#d = defaultdict(int)
#import string
#s = set(string.ascii_letters + string.digits)
#for c in blob:
#    if c not in s:
#        d[c] += 1
#print(d)

rng = range(start_string_char, len(blob), chars_to_count) # range(start, stop, step)
all_chars_to_count = len(blob) - start_string_char
# If all characters to count divided by count step is not an integer, let the user know
if not (all_chars_to_count / chars_to_count).is_integer():
    print(f'Total countable characters {all_chars_to_count} not divisible by character count {chars_to_count}')

newList = []
# TODO: need to find a better way of finding matching characters regardless of start and offsets
for rng_set in rng:
    #c = collections.Counter()
    char_set = blob[rng_set:rng_set + chars_to_count]
    newList.append(char_set)
    #print(char_set)

collections.Counter(newList).most_common(common_limit)
