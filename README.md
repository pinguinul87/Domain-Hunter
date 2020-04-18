# Domain-Hunter
This script will automate the process of domain/subdomain discovery and enumeration based on some tools written in GO and Nmap.

Requirements : 

GO - install go
   - add GOPATH to .bash_profile
   - export PATH=$PATH:$(go env GOPATH)/bin
   
ASSETFINDER - domain/subdomain finder written in GO, created by Tomnomnom
            - go get -u github.com/tomnomnom/assetfinder
            
HTPROBE - probes http 
