#include <string>
#include <vector>
#include <ctime>
#include <thread>
#include <mutex>
#include <mex.h>
#include <NIDAQmx.h>


#define mexUsageError()                                                                         \
    mexErrMsgIdAndTxt ( "nidaqI2C:arguments"                                                    \
                      , "Usage:\n"                                                              \
                        "   nidaqI2C('init', device, port, sCLKline, sDTAline)\n"               \
                        "   nidaqI2C('send', data, [newThread = false], [mustSend = false])\n"  \
                        "   nidaqI2C('end')\n"                                                  \
                        "   nidaqI2C('reset')\n"                                                \
                      );
#define mexInitCheck()                                                                          \
    if ( !sendClock                                                                             \
      || !sendTask                                                                              \
       )                                                                                        \
      mexErrMsgIdAndTxt ( "nidaqI2C:notinitialized"                                             \
                        , "nidaqI2C('init',...) must be called before other commands."          \
                        );


#define mexNargChk(errID, nargin, nargout)                                                      \
    { if (nrhs != nargin + 1)                                                                   \
        mexErrMsgIdAndTxt ( errID, "[%s]  Expected %d+1 input arguments, received %d instead."  \
                          , errID, nargin, nrhs                                                 \
                          );                                                                    \
      if (nlhs != nargout)                                                                      \
        mexErrMsgIdAndTxt ( errID, "[%s]  Expected %d output arguments, received %d instead."   \
                          , errID, nargout, nlhs                                                \
                          );                                                                    \
  }
#define mexNargRangeChk(errID, narginMin, narginMax, nargout)                                   \
    { if (nrhs-1 < narginMin || nrhs-1 > narginMax)                                             \
        mexErrMsgIdAndTxt ( errID, "[%s]  Expected (%d-%d)+1 input arguments, received %d instead."   \
                          , errID, narginMin, narginMax, nrhs                                   \
                          );                                                                    \
      if (nlhs != nargout)                                                                      \
        mexErrMsgIdAndTxt ( errID, "[%s]  Expected %d output arguments, received %d instead."   \
                          , errID, nargout, nlhs                                                \
                          );                                                                    \
  }

#define mexStore(container, item)                                                 \
    { mexMakeArrayPersistent(item);                                               \
      container.push_back(item);                                                  \
    }

#define mexRecordPacket(timestamp)                                                \
    if (numBuffered > 0) {                                                        \
      packetTime    = timestamp;                                                  \
      packetSize    = numBuffered;                                                \
      lastTrigger   = 0;                                                          \
      numBuffered   = 0;                                                          \
      bitBuffered   = 0;                                                          \
    }


#define DAQmxErrChk(errID, functionCall)                                          \
    if ( DAQmxFailed(functionCall) ) {                                            \
  	  char                    errBuff[2048] = {'\0'};                             \
      DAQmxGetExtendedErrorInfo(errBuff, 2048);                                   \
      mexErrMsgIdAndTxt(errID, "[%s]  %s", errID, errBuff);                       \
    }

#define DAQmxSend(data)                                                           \
    { DAQmxErrChk ( "nidaqI2C:write"                                              \
                  , DAQmxWriteDigitalLines( sendTask, BUFFER_SEND                 \
                                          , true, 0, DAQmx_Val_GroupByChannel     \
                                          , data, 0, NULL                         \
                                          )                                       \
                  );                                                              \
      DAQmxErrChk ( "nidaqI2C:sendstop", DAQmxWaitUntilTaskDone(sendTask, 1) );   \
      DAQmxErrChk ( "nidaqI2C:sendstop", DAQmxStopTask(sendTask) );               \
      oBit  = 0;                                                                  \
    }

#define DAQmxNextBit(oBit)                                                        \
    if (++oBit >= BUFFER_SEND) {                                                  \
      DAQmxSend(sendData, oBit);                                                  \
    }

#define DAQmxStopAndClear(task, doWait)                                           \
  if (task) {                                                                     \
    if (doWait)                                                                   \
      DAQmxWaitUntilTaskDone(task, 1);                                            \
    DAQmxStopTask           (task);                                               \
    DAQmxClearTask          (task);                                               \
    task              = NULL;                                                     \
  }


//-----------------------------------------------------------------------------
//  Global variables
//-----------------------------------------------------------------------------

TaskHandle            sendClock     = NULL;
TaskHandle            sendTask      = NULL;
std::mutex            sendGuard;

static const size_t   BUFFER_SEND   = 2048;
//static const size_t   BUFFER_SEND   = 4096;
uInt8                 sendData[2 * BUFFER_SEND];
uInt8*                sCLK          = sendData;
uInt8*                sDTA          = sendData + BUFFER_SEND;


static const size_t   MAX_SEND      = BUFFER_SEND * 10;
uInt8                 sendCache[MAX_SEND];
static const int      BITS_PER_BYTE = 8;
int                   bitTest[BITS_PER_BYTE];


//=============================================================================
void resetDAQ(int device)
{
  char         niDevice[100];
  sprintf(niDevice, "Dev%d", device);
  DAQmxResetDevice(niDevice);
}

void cleanup()
{
  DAQmxStopAndClear(sendClock , true );
  DAQmxStopAndClear(sendTask  , false);
}


//=============================================================================
void transmitData(const int numBytes, const uInt8* matBytes, const bool mustSend)
{
  // Don't do anything if already in the process of transmitting
  if (numBytes < 1)                 return;
  if (mustSend)                     sendGuard.lock();
  else if (!sendGuard.try_lock())   return;


  // Trigger low before start of packet
  size_t          oBit          = 0;
  sCLK[oBit]      = 1;          sDTA[oBit]  = 1;            DAQmxNextBit(oBit);
  sCLK[oBit]      = 1;          sDTA[oBit]  = 0;            DAQmxNextBit(oBit);

  // Slave address
  for (int iBit = 0; iBit < 7; ++iBit) {
    sCLK[oBit]    = 0;          sDTA[oBit]  = 0;            DAQmxNextBit(oBit);
    sCLK[oBit]    = 1;          sDTA[oBit]  = 0;            DAQmxNextBit(oBit);
    sCLK[oBit]    = 0;          sDTA[oBit]  = 0;            DAQmxNextBit(oBit);
  }
  
  // Write command
  sCLK[oBit]      = 0;          sDTA[oBit]  = 0;            DAQmxNextBit(oBit);
  sCLK[oBit]      = 1;          sDTA[oBit]  = 0;            DAQmxNextBit(oBit);
  sCLK[oBit]      = 0;          sDTA[oBit]  = 0;            DAQmxNextBit(oBit);

  // Receive ACK  
  sCLK[oBit]      = 0;          sDTA[oBit]  = 0;            DAQmxNextBit(oBit);
  sCLK[oBit]      = 1;          sDTA[oBit]  = 0;            DAQmxNextBit(oBit);
  sCLK[oBit]      = 0;          sDTA[oBit]  = 0;            DAQmxNextBit(oBit);

  // Data bits should be stable during clock high
  for (int iByte = 0; iByte < numBytes; ++iByte) {
    for (int iBit = 0; iBit < BITS_PER_BYTE; ++iBit) {
      const bool  dataBit       = (matBytes[iByte] & bitTest[iBit]) > 0;
      sCLK[oBit]  = 0;          sDTA[oBit]  = dataBit;      DAQmxNextBit(oBit);
      sCLK[oBit]  = 1;          sDTA[oBit]  = dataBit;      DAQmxNextBit(oBit);
      sCLK[oBit]  = 0;          sDTA[oBit]  = dataBit;      DAQmxNextBit(oBit);
    }

    // Receive ACK  
    sCLK[oBit]    = 0;          sDTA[oBit]  = 0;            DAQmxNextBit(oBit);
    sCLK[oBit]    = 1;          sDTA[oBit]  = 0;            DAQmxNextBit(oBit);
    sCLK[oBit]    = 0;          sDTA[oBit]  = 0;            DAQmxNextBit(oBit);
  }

  // Clock low after end of packet
  sCLK[oBit]      = 1;          sDTA[oBit]  = 0;            DAQmxNextBit(oBit);
  sCLK[oBit]      = 1;          sDTA[oBit]  = 1;            DAQmxNextBit(oBit);

  // Fill the remaining bits with the default state
  if (oBit > 0) {
    for (; oBit < BUFFER_SEND; ++oBit) {
      sCLK[oBit]  = 1;          sDTA[oBit]  = 1;
    }
    DAQmxSend(sendData);
  }

  // Allow the next thread to transmit
  sendGuard.unlock();
}


//=============================================================================
void initialize ( int device, int port, int sCLKline, int sDTAline, bool isBigEndian
                , int dataCounter = 0, int sendCounter = 1, float dataRate = 1e6
                )
{
  // (Re-)create tasks
  cleanup();


  //---------------------------------------------------------------------------
  //  NI-DAQ configuration
  //---------------------------------------------------------------------------

  char                          channel[1000];
  const char                    timebase[]  = "80MHzTimebase";
  const int                     halfPeriod  = 80e6 / dataRate / 2;
  //const char                    timebase[]  = "10MHzRefClock";
  //const float                   halfPeriod  = 80e6 / dataRate / 2;

  // TASK :  Use counter as digital sample clock
  DAQmxErrChk( "nidaqI2C:sendclock"    , DAQmxCreateTask("counter", &sendClock) );
  sprintf(channel, "Dev%d/ctr%d", device, sendCounter);
  DAQmxErrChk( "nidaqI2C:counter"      ,  DAQmxCreateCOPulseChanTicks ( sendClock
                                                                      , channel, "", timebase
                                                                      , DAQmx_Val_Low, 0, halfPeriod, halfPeriod
                                                                      ) );
  DAQmxErrChk( "nidaqI2C:countercfg"   , DAQmxCfgImplicitTiming(sendClock, DAQmx_Val_ContSamps, 1) );


  // TASK :  Digital communications task
  DAQmxErrChk( "nidaqI2C:sendtask"     , DAQmxCreateTask("send", &sendTask) );

  //         Use CLK and DTA lines for output
  sprintf(channel                       , "Dev%d/port%d/line%d", device, port, sCLKline);
  DAQmxErrChk( "nidaqI2C:sendCLK"      , DAQmxCreateDOChan(sendTask, channel, "CLK", DAQmx_Val_ChanPerLine));
  sprintf(channel                       , "Dev%d/port%d/line%d", device, port, sDTAline);
  DAQmxErrChk( "nidaqI2C:sendDTA"      , DAQmxCreateDOChan(sendTask, channel, "DTA", DAQmx_Val_ChanPerLine));

  //         Use sample clock to time digital output
  sprintf(channel                       , "/Dev%d/Ctr%dInternalOutput", device, sendCounter);
  DAQmxErrChk( "nidaqI2C:sendsampling" , DAQmxCfgSampClkTiming(sendTask, channel, dataRate, DAQmx_Val_Rising, DAQmx_Val_FiniteSamps, BUFFER_SEND) );

  //         Use onboard circular buffer and transfer data when half empty
  //DAQmxErrChk( "nidaqI2C:sendregen"    , DAQmxSetWriteRegenMode(sendTask, DAQmx_Val_AllowRegen) );
  DAQmxErrChk( "nidaqI2C:sendregen"    , DAQmxSetWriteRegenMode(sendTask, DAQmx_Val_DoNotAllowRegen) );
  DAQmxErrChk( "nidaqI2C:sendxfer"     , DAQmxSetDODataXferReqCond(sendTask, "", DAQmx_Val_OnBrdMemHalfFullOrLess) ); 
  //DAQmxErrChk( "nidaqI2C:sendnsamples" , DAQmxRegisterEveryNSamplesEvent(sendTask, DAQmx_Val_Transferred_From_Buffer, BUFFER_SEND, 0, &regenerateData, NULL) );

  //         Configure length of RAM buffer
  DAQmxErrChk( "nidaqI2C:outbuffer"    , DAQmxCfgOutputBuffer(sendTask, BUFFER_SEND) );

  //         This task should be committed to improve performance in software restart
  DAQmxErrChk( "nidaqI2C:sendcommit"   , DAQmxTaskControl(sendTask, DAQmx_Val_Task_Commit) );


  //---------------------------------------------------------------------------

  // Ensure transmission of most significant bit first
  if (isBigEndian) {
    for (int iBit = 0; iBit < BITS_PER_BYTE; ++iBit)
      bitTest[iBit]   = ( 1 << iBit );
  } else {
    for (int iBit = 0; iBit < BITS_PER_BYTE; ++iBit)
      bitTest[iBit]   = ( 1 << (BITS_PER_BYTE-1 - iBit) );
  }

  // Turn off Matlab memory management
  mexAtExit(&cleanup);
}


//=============================================================================
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
  //----- Parse arguments
  if (nrhs < 1 || !mxIsChar(prhs[0]))
    mexUsageError();
  
  char                        command[100];
  mxGetString(prhs[0], command, 100);


  //----- Initialization mode
  if (std::strcmp(command, "init") == 0) {
    mexNargChk ("nidaqI2C:init", 4, 0);

    // Determine whether data is least significant or most significant bit first
    mxArray*                  cmpLHS[3];
    mxArray*                  cmpRHS[1];
    mexCallMATLAB(3, cmpLHS, 0, cmpRHS, "computer");
    const char*               endianness  = mxArrayToString(cmpLHS[2]);

    // Setup NI-DAQ lines
    initialize( static_cast<int>( mxGetScalar(prhs[1]) )
              , static_cast<int>( mxGetScalar(prhs[2]) )
              , static_cast<int>( mxGetScalar(prhs[3]) )
              , static_cast<int>( mxGetScalar(prhs[4]) )
              , endianness[0] == 'B'
              );

    // Start tasks in order of dependencies
    DAQmxErrChk( "nidaqI2C:samplestart", DAQmxStartTask(sendClock) );
  }

  //----- Send mode
  else if (std::strcmp(command, "send") == 0) {
    mexNargRangeChk("nidaqI2C:send", 1, 3, 0);
    mexInitCheck();

    // Options: start a new thread, and if NI-DAQ card is busy, can wait 
    // until message can be sent (if not allows loss of messages)
    const bool        newThread     = ( nrhs > 2 && mxGetScalar(prhs[2]) > 0 );
    const bool        mustSend      = ( nrhs > 3 && mxGetScalar(prhs[3]) > 0 );

    // Obtain number of bytes to transmit, depending on data type
    const int         numBytes      = mxGetNumberOfElements(prhs[1])
                                    * mxGetElementSize(prhs[1])
                                    ;
    const uInt8*      matBytes      = (const uInt8*) mxGetData(prhs[1]);

    // Transmit bytes in a separate thread
    if (newThread) {
      if (numBytes > MAX_SEND)
        mexErrMsgIdAndTxt("nidaqI2C:overflow", "Cannot send more than %d bytes in background; data was %d bytes.", MAX_SEND, numBytes);

      std::copy(matBytes, matBytes + numBytes, sendCache);
      std::thread     sendThread(transmitData, numBytes, sendCache, mustSend);
      sendThread.detach();
    }

    // Transmit bytes and wait until done
    else transmitData(numBytes, matBytes, true);
  }

  //----- Cleanup mode
  else if (std::strcmp(command, "end") == 0) {
    mexNargChk("nidaqI2C:end", 0, 0);
    cleanup();
  }

  //----- Reset device
  else if (std::strcmp(command, "reset") == 0) {
    mexNargChk("nidaqI2C:end", 1, 0);
    cleanup();
    resetDAQ(static_cast<int>( mxGetScalar(prhs[1]) ));
  }

  //----- Unsupported command
  else  mexUsageError();
}
