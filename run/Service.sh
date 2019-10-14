ms="$(date +"%N")";
prefix="$(date +"%Y-%m-%dT%T").${ms:0:6} - service.py - ";
successtring="$prefix[SUCCESS]"
errorstring="$prefix[ERROR] check log/service.log";

echo 'running...'
if /root/.local/share/virtualenvs/usiwatch-DG2s277z/bin/python /root/code-server/project/usiwatch/server/service.py 1>/dev/null 2>>log/service.log ; then
    echo "$successstring" >> log/run.log;
    echo 'ok.';
    
else
    echo "$errorstring" >> log/run.log;
    echo 'error. Check log/service.log';

fi