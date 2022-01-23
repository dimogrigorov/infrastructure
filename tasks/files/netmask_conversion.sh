nbits=0
    IFS=.
    subnetmask=$1
    for dec in $subnetmask; do
            case $dec in
                    255) let nbits+=8;;
                    254) let nbits+=7 ; break ;;
                    252) let nbits+=6 ; break ;;
                    248) let nbits+=5 ; break ;;
                    240) let nbits+=4 ; break ;;
                    224) let nbits+=3 ; break ;;
                    192) let nbits+=2 ; break ;;
                    128) let nbits+=1 ; break ;;
                    0);;
            esac
    done
    echo "$nbits"
