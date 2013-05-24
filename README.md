# LUNperf

A bash script that uses lsscsi and dd to run read & write performance tests against data LUN’s. The results are outputted to a text file.

## Install

Copy lunperf.sh file to the host from which you want to run the performance tests. Setup your lunexclude.txt in the same directory as lunperf.sh and include the LUN paths that you don’t want to run the tests against in the lunexclude.txt file. For example:

/dev/sda   
/dev/sdb

Would exclude /dev/sda and /dev/sdb from being tested.

## Usage

```
lunperf.sh [-r] [-w] [-v vendor_name] [-e excluded_lun_file] [-d ouput_dir] [-s blocksize] [-c countsize]
```

####OPTIONS:
-r Read Test         
-w Write Test        
-v LUN Vendor. Run lsscsi to see list of vendors (required for write test)    
-e Exclude LUNs file. Example, /dev/sda in file lunexclude.txt   
-d Performace results output directory. Default is /tmp    
-s Block size. Default is 1M    
-c Block count (required)   

## Copyright 

Copyright (c) 2012-2013 JD Trout
