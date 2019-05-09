function vr = TCPIPcomm_laser(command,vr)

switch command
    case 'init'
        
        temp = instrfindall('Status','open','Type','tcpip');
        if ~ isempty(temp)
            fclose(instrfindall);
        end
        vr.tcpip.tcpObj = tcpip(RigParameters.laserIP,80,'NetworkRole','Client');
        fopen(vr.tcpip.tcpObj);
        
    case 'send'
        
        if ischar(vr.tcpip.dataOut)
            fprintf(vr.tcpip.tcpObj,vr.tcpip.dataOut);
        else
            fwrite(vr.tcpip.tcpObj,vr.tcpip.dataOut);
        end
        
    case 'receiveString'

        vr.tcpip.dataIn = fscanf(vr.tcpip.tcpObj);
        vr.tcpip.dataIn = vr.tcpip.dataIn(1:end-1);
        
    case 'receiveData'

        vr.tcpip.dataIn = fread(vr.tcpip.tcpObj,vr.tcpip.datasize,'double');
        
    case 'end'
        
        temp = instrfindall('Status','open','Type','tcpip');
        if ~isempty(temp)
            fclose(vr.tcpip.tcpObj);
        end
end