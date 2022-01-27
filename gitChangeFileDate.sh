# Change local file dates to their Git time
rev=HEAD
for f in $(git ls-tree -r -t --full-name --name-only "$rev") ; do
    touch -t $(git log --pretty=format:%cd --date=format:%Y%m%d%H%m.%S -1 "$rev" -- "$f") "$f";
done
