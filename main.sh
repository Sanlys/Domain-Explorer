#!/bin/bash

domain="example.com" #Domain to enumerate

knockpydir="" #Directory for the knockpy.py file. https://github.com/guelfoweb/knock

mkdir tmp
rm ./tmp/* #Removes potential junk in the tmp folder
rm final.json
python $knockpydir $domain -o ./tmp 

cat ./tmp/*.json | jq keys > ./tmp/subdomains #Parse json, gets subdomains from the raw json data

sed -i '$d' ./tmp/subdomains #Removes the first line, uneccesary json syntax
sed -i '1d' ./tmp/subdomains #Removes the last line, uneccesary json syntax
sed -i '/"_meta"/d' ./tmp/subdomains #Removes _meta, uneccesary information from the knockpy script
sed -i 's/[[:blank:]]//g' ./tmp/subdomains #Removes whitespace except newlines
sed -i 's/\"//g' ./tmp/subdomains #Removes quotes
sed -i 's/\,//g' ./tmp/subdomains #Removes commas

rm ./tmp/*.json #Removes the json file generated from knockpy, no longer needed

for i in $(cat ./tmp/subdomains); do dig $i +short | head -n1 >> ./tmp/ips; done #Resolves each domain to an IP and saves it to a file

echo "[]" > final.json

for ((i = 1; i<$(wc -l < ./tmp/ips); i++));
do
    subdomain=$(head -$i tmp/subdomains | tail +$i)
    ip=$(head -$i tmp/ips | tail +$i)
    echo $subdomain $ip
    nmap -A $ip -oX ./tmp/xml --reason
    nmap2json convert ./tmp/xml --save ./tmp/out.json > /dev/null #gem install nmap2json
    nmapJson=$(cat ./tmp/out.json)
    JSON_STRING=$(jq -n \
                      --arg s "$subdomain" \
                      --arg i "$ip" \
                      --argjson n "$nmapJson" \
                      '{subdomain: $s, ip: $i, nmap: $n}'
                      )
    echo $(jq --argjson x "$JSON_STRING" '. += [$x]' final.json) > final.json
done
rm -r tmp
