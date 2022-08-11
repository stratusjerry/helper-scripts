import hashlib
import os
import difflib

dir1="/tmp/dir1"
dir2="/tmp/dir2"

# Create a dict of basedir filepath and md5sum
def get_path_hash(basedir):
    basedirDict = {}
    for root, dirs, files in os.walk(basedir):
        for fileName in files:
            path = os.path.join(root, fileName)
            #print(path)
            hashObj = hashlib.md5()
            with open(path, 'rb') as fileToHash:
                fileContents = fileToHash.read()
                hashObj.update(fileContents)
            #print(hashObj.hexdigest())
            basedirDict[path] = hashObj.hexdigest()
            #print(f'Path {path} Hash {hashObj.hexdigest()}')
    return basedirDict


def strip_dir_path(dirPrePath, dirDict):
    strippedDict = {}
    for k, v in dirDict.items():
        strippedPath = k.replace(dirPrePath,"")
        #print(f'Stripped Path {strippedPath}')
        strippedDict[strippedPath] = v
    return strippedDict


def compare_files(dir1Dict, dir2Dict, foundBoolean = True):
    foundList = [] ; missingList = [] ; totalFound = 0 ; totalMissing = 0
    for dir1Key, dir1Value in dir1Dict.items():
        #strip the preceding directory path so we can compare
        if dir1Key in dir2Dict:
            print(f'Exists: {dir1Key}')
            totalFound += 1
            foundList.append(dir1Key)
        else:
            print(f'Missing: {dir1Key}')
            totalMissing += 1
            missingList.append(dir1Key)
        dir1Key.replace(dir1,"")
    print(f"    Total files Found: {totalFound} Missing: {totalMissing}")
    if foundBoolean:
        return foundList
    else:
        return missingList


def compare_hash(foundFiles, dir1Dict, dir2Dict):
    hashNotMatch = [] ; totalMatching = 0 ; totalNotMatching = 0
    for file in foundFiles:
        dir1DictFileHash = dir1Dict[file]
        dir2DictFileHash = dir2Dict[file]
        if dir1DictFileHash == dir2DictFileHash:
            totalMatching += 1
            print(f"Match File: {file} Dir1Value: {dir1DictFileHash} Dir2Value: {dir2DictFileHash}")
        else:
            totalNotMatching += 1
            print(f"  No Match File: {file} Dir1Value: {dir1DictFileHash} Dir2Value: {dir2DictFileHash}")
            hashNotMatch.append(file)
    print(f"    Total files Matching: {totalMatching} Not Matching: {totalNotMatching}")
    return hashNotMatch


def diff_files(file1, file2):
    print(f'############### File Differences: {file1} AND {file2} ###############')
    text1 = open(file1, 'r').readlines()
    text2 = open(file2, 'r').readlines()
    for line in difflib.unified_diff(text1, text2):
        print(line)


dir1Dict = get_path_hash(dir1)
strippedDir1Dict = strip_dir_path(dir1, dir1Dict)
dir2Dict = get_path_hash(dir2)
strippedDir2Dict = strip_dir_path(dir2, dir2Dict)
foundFiles = compare_files(strippedDir1Dict, strippedDir2Dict)
missingDir2Files = compare_files(strippedDir2Dict, strippedDir1Dict, foundBoolean = False) #Compare Dir2 Files missing in Dir1

hashMismatch = compare_hash(foundFiles, strippedDir1Dict, strippedDir2Dict)

for mismatch in hashMismatch:
    file1 = dir1 + mismatch
    file2 = dir2 + mismatch
    diff_files(file1, file2)
    print(file1)
