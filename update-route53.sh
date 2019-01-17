#!/bin/bash

# (optional) You might need to set your PATH variable at the top here
# depending on how you run this script
#PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Hosted Zone ID e.g. BJBK35SKMM9OE
ZONEID=$ZONEID

# The CNAME you want to update e.g. hello.example.com
RECORDSET=$RECORDSET

SLEEPSECS=$SLEEPSECS

# More advanced options below
# The Time-To-Live of this recordset
TTL=$TTL
# Change this if you want
COMMENT="Auto updating @ `date`"
# Change to AAAA if using an IPv6 address
TYPE="A"

# Get the external IP address from OpenDNS (more reliable than other providers)
IP=`dig +short myip.opendns.com @resolver1.opendns.com`

function valid_ip()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

function update_dns() {
    # Get current dir
    # (from http://stackoverflow.com/a/246128/920350)
    DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    IPFILE="$DIR/update-route53.ip"

    if ! valid_ip $IP; then
        echo "Invalid IP address: $IP"
        return
    fi

    # Check if the IP has changed
    if [ ! -f "$IPFILE" ]
        then
        touch "$IPFILE"
    fi

    if grep -Fxq "$IP" "$IPFILE"; then
        # code if found
        echo "IP is still $IP. Returning" 
        return
    else
        echo "IP has changed to $IP" 
        # Fill a temp file with valid JSON
        TMPFILE=$(mktemp /tmp/temporary-file.XXXXXXXX)
        cat > ${TMPFILE} << EOF
        {
        "Comment":"$COMMENT",
        "Changes":[
            {
            "Action":"UPSERT",
            "ResourceRecordSet":{
                "ResourceRecords":[
                {
                    "Value":"$IP"
                }
                ],
                "Name":"$RECORDSET",
                "Type":"$TYPE",
                "TTL":$TTL
            }
            }
        ]
        }
EOF
        # Update the Hosted Zone record
        aws route53 change-resource-record-sets \
            --hosted-zone-id $ZONEID \
            --change-batch file://"$TMPFILE" 

        # Clean up
        rm $TMPFILE
    fi

    # All Done - cache the IP address for next time
    echo "$IP" > "$IPFILE"
}

while true
do 
    echo running...
    update_dns
    sleep $SLEEPSECS
done