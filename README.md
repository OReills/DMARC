# DMARC
This script has been created to extract the DMARC records for a list of domains and to extract it to a .csv file. it is useful if you want to check the DMARC policy for a number of domains at one time. 

The domain list should be cerated - create a .txt with your list of _dmarc.domain.com, one per line and specified in the filelist part of the script.

an email address can also be configured under notifications by setting this to =1
email_list = your email address - mutt is used for this operation. 
