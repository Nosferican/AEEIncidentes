FILEPATH=`date +%Y-%m-%dT%H.jsonl`
INPUT="data/sectors.txt"
while IFS=: read -r sector
do
    curl -s https://micuenta.prepa.com:9443/micuenta/api/outage/sectors/$sector >> $FILEPATH
    echo "" >> $FILEPATH
done <"$INPUT"
