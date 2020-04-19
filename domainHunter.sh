#!/bin/bash
: '
This script needs to be executed with sudo/root privileges.
Usage : ./domainHunter.sh <URL>
'

SECONDS=0
target=$1

#Create directory structure, one line
mkdir -p ~/$target/recon/{scans,httprobe,potential_takeovers,wayback/{params,extensions}}

#Create alive.txt and final.txt 
if [ ! -f "~/$target/recon/httprobe/alive.txt" ];then
    touch ~/$target/recon/httprobe/alive.txt
fi
if [ ! -f "~/$target/recon/final.txt" ];then
    touch ~/$target/recon/final.txt
fi

#Check if all necessary tools are installed and istall them if not.
if [ ! -x "$(command -v assetfinder)" ]; then
       echo "[-] Assetfinder not found. Installing Assetfinder from https://github.com/tomnomnom/assetfinder "
       go get -u github.com/tomnomnom/assetfinder
       echo "[+] Assetfiner installed."     
fi

if [ ! -x "$(command -v httprobe)" ]; then
       echo "[-] Httprobe not found. Installing Httprobe from https://github.com/tomnomnom/httprobe "
       go get -u github.com/tomnomnom/httprobe
       echo "[+] Httprobe installed."       
fi

if [ ! -x "$(command -v nmap)" ]; then
       echo "[-] Nmap not found. Installing Nmap. "
        
       declare -A osInfo;
       osInfo[/etc/debian_version]="apt-get install -y"
       osInfo[/etc/alpine-release]="apk --update add"
       osInfo[/etc/centos-release]="yum install -y"
       osInfo[/etc/fedora-release]="dnf install -y"

       for i in ${!osInfo[@]}
       do
            if [[ -f $i ]];then
            package_manager=${osInfo[$i]}
       fi
       done

       package="nmap"
       ${package_manager} ${package}
       
       echo "[+] Nmap installed."      
fi

if [ ! -x "$(command -v subjack)" ]; then
       echo "[-] Subjack not found. Please install Subjack from https://github.com/haccer/subjack "
       go get -u github.com/haccer/subjack
       echo "[+] Subjack installed."       
fi

if [ ! -x "$(command -v waybackurls)" ]; then
       echo "[-] Waybackurls not found. Please install Waybackurls from https://github.com/tomnomnom/waybackurls "
       go get -u github.com/tomnomnom/waybackurls
       echo "[+] Waybackurls installed."       
fi

echo "[+] Finding subdomains with Assetfinder ..."
assetfinder $target >> ~/$target/recon/assets.txt
cat ~/$target/recon/assets.txt | grep $1 >> ~/$target/recon/final.txt
rm ~/$target/recon/assets.txt
 
echo "[+] Probing for alive domains with Httprobe ..."
cat ~/$target/recon/final.txt | sort -u | httprobe -s -p https:443 | sed 's/https\?:\/\///' | tr -d ':443' >> ~/$target/recon/httprobe/a.txt
sort -u ~/$target/recon/httprobe/a.txt > ~/$target/recon/httprobe/alive.txt
rm ~/$target/recon/httprobe/a.txt
 
echo "[+] Checking for possible subdomain takeover ..."
if [ ! -f "~/$target/recon/potential_takeovers/potential_takeovers.txt" ];then
    touch ~/$target/recon/potential_takeovers/potential_takeovers.txt
fi
 
subjack -w ~/$target/recon/final.txt -t 100 -timeout 30 -ssl -c ~/go/src/github.com/haccer/subjack/fingerprints.json -v 3 -o ~/$target/recon/potential_takeovers/potential_takeovers.txt
 
echo "[+] Scanning for open ports with Nmap ..."
nmap -iL ~/$target/recon/httprobe/alive.txt -T4 -oA ~/$target/recon/scans/scanned.txt
 
echo "[+] Scraping wayback data ..."
cat ~/$target/recon/final.txt | waybackurls >> ~/$target/recon/wayback/wayback_output.txt
sort -u ~/$target/recon/wayback/wayback_output.txt
 
echo "[+] Pulling and compiling all possible params found in wayback data ..."
cat ~/$target/recon/wayback/wayback_output.txt | grep '?*=' | cut -d '=' -f 1 | sort -u >> ~/$target/recon/wayback/params/wayback_params.txt
for line in $(cat ~/$target/recon/wayback/params/wayback_params.txt);do 
    echo $line'='
done
 
echo "[+] Pulling and compiling js/php/aspx/jsp/json files from wayback output ..."
for line in $(cat ~/$target/recon/wayback/wayback_output.txt);do
    ext="${line##*.}"
    if [[ "$ext" == "js" ]]; then
        echo $line >> ~/$target/recon/wayback/extensions/js1.txt
        sort -u ~/$target/recon/wayback/extensions/js1.txt >> ~/$target/recon/wayback/extensions/js.txt
    fi
    if [[ "$ext" == "html" ]];then
        echo $line >> ~/$target/recon/wayback/extensions/jsp1.txt
        sort -u ~/$target/recon/wayback/extensions/jsp1.txt >> ~/$target/recon/wayback/extensions/jsp.txt
    fi
    if [[ "$ext" == "json" ]];then
        echo $line >> ~/$target/recon/wayback/extensions/json1.txt
        sort -u ~/$target/recon/wayback/extensions/json1.txt >> ~/$target/recon/wayback/extensions/json.txt
    fi
    if [[ "$ext" == "php" ]];then
        echo $line >> ~/$target/recon/wayback/extensions/php1.txt
        sort -u ~/$target/recon/wayback/extensions/php1.txt >> ~/$target/recon/wayback/extensions/php.txt
    fi
    if [[ "$ext" == "aspx" ]];then
        echo $line >> ~/$target/recon/wayback/extensions/aspx1.txt
        sort -u ~/$target/recon/wayback/extensions/aspx1.txt >> ~/$target/recon/wayback/extensions/aspx.txt
    fi
done
 
rm ~/$target/recon/wayback/extensions/js1.txt
rm ~/$target/recon/wayback/extensions/jsp1.txt
rm ~/$target/recon/wayback/extensions/json1.txt
rm ~/$target/recon/wayback/extensions/php1.txt
rm ~/$target/recon/wayback/extensions/aspx1.txt

ELAPSED="Elapsed: $(($SECONDS / 3600))hrs $((($SECONDS / 60) % 60))min $(($SECONDS % 60))sec"
echo $ELAPSED
echo "[+] End of script."
