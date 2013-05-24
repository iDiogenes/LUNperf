#!/bin/bash
######################################################
#
# lunperf.sh
# Perform LUN read and write performance tests. Please use with cation as data loss can occur
# By default performance numbers are written to /tmp/lunperf_datetime
#
# JD Trout 
# 7/20/2012 v.0.1
#
# Known Issues
# * lunexclude.txt can have issues if vendor already remove
#
#
######################################################

#Default Globals
FILENAME="lunperf_$(date +"%y%m%d%H%M").txt"
DIR="/tmp"
EXCLUDE=lunexclude.txt
SIZE=1M


# function to show how to use the script
usage()
{
cat << EOF
usage: $0 [-r] [-w] [-v vendor_name] [-e excluded_lun_file] [-d ouput_dir] [-s blocksize] [-c countsize]

OPTIONS:
   -r      Read Test  
   -w      Write Test
   -v      LUN Vendor. Run lsscsi to see list of vendors (require for write)
   -e      Exclude LUNs file. Example, /dev/sda in file lunexclude.txt
   -d      Performace results output directory. Default is /tmp
   -s	   Block size. Default is 1M
   -c      Block count (required)
EOF
}

# function to compair arrays
diff()
{
	awk 'BEGIN{RS=ORS=" "}
    	{NR==FNR?a[$0]++:a[$0]--}
    	END{for(k in a)if(a[k])print k}' <(echo -n "${!1}") <(echo -n "${!2}")
}

# create lunexclude.txt file if it does not exist
createexclude()
{
	cat << EOF
# This is file is used for LUN exclusion. Please use the full path.
# Failure to properly specify excluded LUN's can lead to DATA LOSS!
# Example:
# /dev/sda
# /dev/sdc
EOF
} > $EXCLUDE

# progress bar
progbar() 
{
    dots="....."
    i=0
    j=1
    first=1
    while [ -d /proc/$1 ]; do
        if [[ $first == 1 ]] 
			then
            first=0
        else
            ########## Moved ########
            sleep .5
            printf "\b\b\b\b\b\b\b\b"
            #########################
            if [ $i -eq 6 ]; then
                j=$(($j * -1))
                i=$(($i -2))
            elif [ $i -eq 0 ];then
                j=$(($j * -1))
            fi
        fi
        # B&W
        printf "[%s|%s]" "${dots:0:$i}" "${dots:0:$((5 -$i))}"
        i=$(($i + $j))

    done
    wait $!
    out=$?
    if [[ $out == 0 ]]
		then
        printf "\t[ \e[0;32mSuccess\e[m ]\n"
    else
        printf "\t[ \e[0;31mFailure\e[m ]\n"
    fi
    echo ""
    return $out
}

cvlabcheck()
{
	lsArray=($(lsscsi | awk '{print $(NF)}'))
	cvArray=($(cvlabel -c | grep -v CvfsDisk_UNKNOWN | awk '{print $(2)}'))
	echo ${lunArray[@]}
	
}

cvlabcheck
#START SCRIPT EXECUTION

# get options

while getopts “rwv:e:d:s:c:” OPTION
do
     case $OPTION in
         r)
             READ=1
             ;;
         w)
             WRITE=1
             ;;
         v)
             VEN=$OPTARG
             ;;
         e)
             EXCLUDE=$OPTARG
             ;;
         d)
             DIR=$OPTARG
             ;;
         s)
             SIZE=$OPTARG
             ;;
         c)
             COUNT=$OPTARG
             ;;
     esac
done

if ! [ -e $EXCLUDE ]
	then
	echo -e "LUN exclusion file not found."
	echo -e "creating LUN exclusion file lunexclude.txt\n"
	createexclude
	if [[ -e $EXCLUDE ]]
		then
		echo -e "lunexclude.txt created succesfully!"
		echo -e "please see file for details.\n"
	else
		echo -e "lunexclude.txt unable to be created!\n"
	fi
fi	
	

if ! [ -d $DIR ]
	then
	echo "Directory " $DIR " does not exist"
	usage
	exit 1
fi

if [[ -z $COUNT ]]
	then
    echo "Block count not specified"
    usage
    exit 1
fi

if [[ -z $VEN ]]
	then
    echo "Disk Vendor not specified ONLY READ test permitted"
    READ=1
	WRITE=0
	totallunArray=($(lsscsi | awk '{print $(NF)}'))	# create array of device paths without vender ID	
fi

if [[ -z $READ && -z $WRITE  ]]
	then
    echo "Please select read (-r) and/or write options (-w) "
    usage
    exit 1
fi

if [[ $WRITE == 1 ]]
	then
    echo -e "***Writing to raw LUN's can cause DATA LOSS are you sure you wish to continue???***"
    read -p "[y/n]" ANS
	ANS=($(echo $ANS | tr '[A-Z]' '[a-z]'))
    if [ $ANS == "y" -o $ANS == "yes" ]
		then
		echo "You chose yes, good luck!"
	else
    	exit 1
	fi
fi

if [[ -z $totallunArray ]]
	then
	totallunArray=($(lsscsi | grep -i $VEN | awk '{print $(NF)}')) # create array of device paths
fi

# create array of excluded device paths
while read -r exlunArray
do
    [[ $exlunArray = \#* ]] && continue
    exlunArray=( "${exlunArray[@]}" $exlunArray)
done < $EXCLUDE

# remove dup device paths
lunArray=($(diff exlunArray[@] totallunArray[@]))

# get length of the array
LEN=${#lunArray[@]}

# file output
FILEOUT=$DIR/$FILENAME

# state start time
echo "lunperf.sh starting at $(date)" >> $FILEOUT

ddtest()
{
# loop through array
for (( i=0; i<${LEN}; i++ ));
do
 	LUNPATH="${lunArray[$i]}"
  
	if [[ $READ == 1 ]]
		then
  		echo "read speed test for LUN $LUNPATH" >> $FILEOUT
  		dd if=$LUNPATH of=/dev/null bs=$SIZE count=$COUNT 2>> $FILEOUT
	    if [[ $? != 0 ]]
			then
			exit 1
		fi
 	fi
	echo -e "\n" >> $FILEOUT
	
	if [[ $WRITE == 1 ]]
		then
		echo "write speed test for LUN $LUNPATH" >> $FILEOUT
  		dd if=/dev/zero of=$LUNPATH bs=$SIZE oflag=direct count=$COUNT 2>> $FILEOUT
	    if [[ $? != 0 ]]
			then
			exit 1
		fi
	fi
	
	echo -e "\n" >> $FILEOUT
done
	
# state finished time
echo "lunperf.sh compleated at $(date)" >> $FILEOUT
}

# run test with progress bar
ddtest & progbar $!

# make sure everything compleated successfuly
if [[ $out == 0 ]]
	then
	echo -e "lunperf.sh compleated - please see $FILEOUT for results."
fi

if ! [ -e $FILEOUT ]
	then
	echo -e "Error - $FILEOUT was not able to be created!"
fi

#EOF