FILEPATH=/github/workspace/data`date +%Y-%m-%dT%H.jsonl`
INPUT="/github/workspace/data/sectors.txt"
while IFS=: read -r sector
do
    curl -s https://micuenta.prepa.com:9443/micuenta/api/outage/sectors/$sector >> $FILEPATH
    echo "" >> $FILEPATH
done <"$INPUT"
