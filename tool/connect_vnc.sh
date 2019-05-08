if [ $# -lt 2 ];
then 
    echo "Usage: ./connet_vnc.sh username domain"
    exit 0
fi

username=$1
domain=$2

ssh -fNT "$username"@"$domain" -L 5900:localhost:5900 &&
remmina ||
echo "Can't connect to $domain. Perhaps you should first copy your public key to remote server."
