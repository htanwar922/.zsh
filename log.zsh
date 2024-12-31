# Log output manipulation functions

function add-timestamp {
    # ts '[%Y-%m-%d %H:%M:%S]'
    while read line; do echo "[$(date +'%Y-%m-%d %H:%M:%S.%3N')] $line"; done
}
