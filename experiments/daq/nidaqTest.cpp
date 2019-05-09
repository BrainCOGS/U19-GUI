#include <string>
#include <vector>
#include <ctime>
#include <thread>
#include <chrono>
#include <mex.h>
#include <NIDAQmx.h>


#define mexUsageError()                                                                       \
    mexErrMsgIdAndTxt ( "nidaqTest:arguments"                                                 \
                      , "Usage:\n"                                                            \
                        "   nidaqTest('init', device, port, sCLKline, rCLKline, tCLKline, sDTAline, rDTAline, sTRGline, rTRGline)\n"  \
                        "   nidaqTest('send', uint8(data), doWait)\n"                         \
                        "   [data, timeelapsed] = nidaqTest('receive', maxWaitSecs)\n"        \
                        "   nidaqTest('end')\n"                                               \
                        "   nidaqTest('reset')\n"                                             \
                      );
#define mexInitCheck()                                                                        \
    if ( !dataTask                                                                            \
      || !sendClock                                                                           \
      || !sendTask                                                                            \
       )                                                                                      \
    mexErrMsgIdAndTxt ( "nidaqTest:notinitialized"                                            \
                      , "nidaqTest('init',...) must be called before other commands."         \
                      );


#define mexNargChk(errID, nargin, nargout)                                                    \
    if (nrhs != nargin + 1)                                                                   \
      mexErrMsgIdAndTxt ( errID, "[%s]  Expected %d+1 input arguments, received %d instead."  \
                        , errID, nargin, nrhs                                                 \
                        );                                                                    \
    if (nlhs != nargout)                                                                      \
      mexErrMsgIdAndTxt ( errID, "[%s]  Expected %d output arguments, received %d instead."   \
                        , errID, nargout, nlhs                                                \
                        );

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
    DAQmxErrChk ( "nidaqTest:write"                                               \
                , DAQmxWriteDigitalLines( sendTask, BUFFER_SEND                   \
                                        , true, 0, DAQmx_Val_GroupByChannel       \
                                        , data, 0, NULL                           \
                                        )                                         \
                );                                                                \
    DAQmxErrChk ( "nidaqTest:sendstop", DAQmxWaitUntilTaskDone(sendTask, 1) );    \
    DAQmxErrChk ( "nidaqTest:sendstop", DAQmxStopTask(sendTask) );                \
    oBit  = 0;                                                                    \

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
//  Receive
//-----------------------------------------------------------------------------


const std::chrono::milliseconds     T_SLEEP   = std::chrono::milliseconds(1);

TaskHandle            dataTask      = NULL;

static const size_t   BUFFER_RECV   = 8192;
static const size_t   BUFFER2_RECV  = 2*BUFFER_RECV;
uInt8                 recvData[3 * BUFFER_RECV];
char                  recvBuffer[BUFFER2_RECV];
uInt8                 lastTrigger   = 0;
size_t                numBuffered   = 0;
size_t                bitBuffered   = 0;

double                packetTime    = -999;
size_t                packetSize    = 0;


//-----------------------------------------------------------------------------
//  Send
//-----------------------------------------------------------------------------

TaskHandle            sendClock     = NULL;
TaskHandle            sendTask      = NULL;
std::chrono::high_resolution_clock::time_point  \
                      tLastSend;

static const size_t   BUFFER_SEND   = 2048;
//static const size_t   BUFFER_SEND   = 4096;
uInt8                 NOTHING [3 * BUFFER_SEND];
uInt8                 sendData[3 * BUFFER_SEND];
uInt8*                sTRG          = sendData;
uInt8*                sCLK          = sendData +   BUFFER_SEND;
uInt8*                sDTA          = sendData + 2*BUFFER_SEND;


static const size_t   MAX_SEND      = BUFFER_SEND * 10;
uInt8                 sendCache[MAX_SEND];


//=============================================================================
void resetDAQ(int device)
{
  char         niDevice[100];
  sprintf(niDevice, "Dev%d", device);
  DAQmxResetDevice(niDevice);
}

void cleanup()
{
  DAQmxStopAndClear(dataTask  , true );
  DAQmxStopAndClear(sendClock , true );
  DAQmxStopAndClear(sendTask  , false);

  lastTrigger   = 0;
  numBuffered   = 0;
  bitBuffered   = 0;
  packetTime    = -999;
  packetSize    = 0;
}


//=============================================================================
void transmitData(const int numBytes, const uInt8* matBytes)
{
  if (numBytes < 1)             return;
  tLastSend       = std::chrono::high_resolution_clock::now();


  // Trigger low before start of packet
  size_t          oBit          = 0;
  sTRG[oBit]      = 0;          sCLK[oBit]  = 0;          sDTA[oBit]  = 1;            DAQmxNextBit(oBit);
  sTRG[oBit]      = 0;          sCLK[oBit]  = 1;          sDTA[oBit]  = 1;            DAQmxNextBit(oBit);

  // Data bits should be stable during clock high
  for (int iByte = 0; iByte < numBytes; ++iByte) {
    for (int iBit = 0; iBit < 8; ++iBit) {
      const bool  dataBit       = (matBytes[iByte] & (1 << iBit)) > 0;
      sTRG[oBit]  = 1;          sCLK[oBit]  = 0;          sDTA[oBit]  = dataBit;      DAQmxNextBit(oBit);
      sTRG[oBit]  = 1;          sCLK[oBit]  = 1;          sDTA[oBit]  = dataBit;      DAQmxNextBit(oBit);
      sTRG[oBit]  = 1;          sCLK[oBit]  = 0;          sDTA[oBit]  = dataBit;      DAQmxNextBit(oBit);
    }
  }

  // Trigger and clock low after end of packet
  sTRG[oBit]      = 0;          sCLK[oBit]  = 0;          sDTA[oBit]  = 1;            DAQmxNextBit(oBit);
  sTRG[oBit]      = 0;          sCLK[oBit]  = 1;          sDTA[oBit]  = 1;            DAQmxNextBit(oBit);
  sTRG[oBit]      = 0;          sCLK[oBit]  = 0;          sDTA[oBit]  = 1;            DAQmxNextBit(oBit);

  // Fill the remaining bits with the default state
  if (oBit > 0) {
    for (; oBit < BUFFER_SEND; ++oBit) {
      sTRG[oBit]  = 0;          sCLK[oBit]  = 0;          sDTA[oBit]  = 1;
    }
    DAQmxSend(sendData);
  }
}


//=============================================================================
//int32 CVICALLBACK recordData(TaskHandle task, int32 status, void *callbackData)
//int32 CVICALLBACK recordData(TaskHandle task, int32 signalID, void *callbackData)
//int32 CVICALLBACK recordData(TaskHandle task, int32 everyNsamplesEventType, uInt32 nSamples, void *callbackData)
void recordData()
{
  // Termination condition is if the task is cleared
  while (dataTask)
  {
    // Read acquired data
    int32               nDataRead, nDataBytes;
    int32               error         = DAQmxReadDigitalLines ( dataTask, -1
                                                              , 1, DAQmx_Val_GroupByChannel
                                                              , recvData, 3*BUFFER_RECV
                                                              , &nDataRead, &nDataBytes, NULL
                                                              );

    if (nDataRead < 1) {
      std::this_thread::sleep_for(T_SLEEP);
      continue;
    }
    if (DAQmxFailed(error) || nDataBytes != 1) {
  	  char              errBuff[2048] = {'\0'};
      DAQmxGetExtendedErrorInfo(errBuff, 2048);
      return;
    }

   
    // Record timestamp as soon as possible
    std::chrono::high_resolution_clock::time_point  \
                        tPacket       = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double, std::milli>
                        tElapsed      = tPacket - tLastSend;

    // Software "edge detection"
    const uInt8*        rTRG          = recvData;
    const uInt8*        rDTA          = recvData + nDataRead;
    for (size_t iDatum = 0; iDatum < nDataRead; ++iDatum) {
      // Rising edge -- forcibly terminate last packet 
      if (lastTrigger < 1 && rTRG[iDatum] > 0) {
        mexRecordPacket(tElapsed.count());
      }

      // Record data if trigger is high
      if (rTRG[iDatum] > 0) {
        if (bitBuffered < 1)
          recvBuffer[numBuffered]     = (rDTA[iDatum] > 0);
        else if (rDTA[iDatum] > 0)
          recvBuffer[numBuffered]    |= (1 << bitBuffered);

        // Increment bit and byte if appropriate
        if (++bitBuffered > 7) {
          bitBuffered                 = 0;
          if (++numBuffered > BUFFER2_RECV)
            numBuffered               = 0;      // circular buffer
        }
      }

      // Falling edge -- record last packet
      if (lastTrigger > 0 && rTRG[iDatum] < 1) {
        mexRecordPacket(tElapsed.count());
      }

      // Update last trigger value
      lastTrigger       = rTRG[iDatum];
    }

  }
}


//=============================================================================
void initialize ( int device, int port
                , int sCLKline, int rCLKline, int tCLKline, int sDTAline, int rDTAline, int sTRGline, int rTRGline
                , int dataCounter = 0, int sendCounter = 1, float dataRate = 1e6
                )
{
  char                        channel[1000];
  char                        source[1000];

  // (Re-)create tasks
  cleanup();

  //---------------------------------------------------------------------------
  //  Receive
  //---------------------------------------------------------------------------

  // TASK :  Read data packet
  DAQmxErrChk( "nidaqTest:datatask"     , DAQmxCreateTask("data", &dataTask) );

  //         Read from DTA line with CLK as sample clock
  sprintf(channel                       , "Dev%d/port%d/line%d", device, port, rTRGline);
  DAQmxErrChk( "nidaqTest:dataTRG"      , DAQmxCreateDIChan(dataTask, channel, "TRG", DAQmx_Val_ChanPerLine));
  sprintf(channel                       , "Dev%d/port%d/line%d", device, port, rDTAline);
  DAQmxErrChk( "nidaqTest:dataDTA"      , DAQmxCreateDIChan(dataTask, channel, "DTA", DAQmx_Val_ChanPerLine));
  sprintf(channel                       , "/Dev1/PFI%d", tCLKline);
  DAQmxErrChk( "nidaqTest:datasampling" , DAQmxCfgSampClkTiming(dataTask, channel, 2*dataRate, DAQmx_Val_Rising, DAQmx_Val_ContSamps, BUFFER_RECV) );
  //DAQmxErrChk( "nidaqTest:datasampling" , DAQmxCfgSampClkTiming(dataTask, channel, 2e3, DAQmx_Val_Rising, DAQmx_Val_FiniteSamps, 2) );
  DAQmxErrChk( "nidaqTest:databuffer"   , DAQmxCfgInputBuffer(dataTask, BUFFER_RECV) );

  //         Start trigger is CLK high and DTA transition to low
  //         Stop (reference) trigger is CLK high and DTA transition to high
  //DAQmxErrChk( "nidaqTest:datastart"    , DAQmxCfgDigEdgeStartTrig( dataTask, channel, DAQmx_Val_Rising     ) );
  //DAQmxErrChk( "nidaqTest:dataref"      , DAQmxCfgDigEdgeRefTrig  ( dataTask, channel, DAQmx_Val_Falling, 2 ) );

  //         Fire a software event for change detection


  //         Read relative to start trigger whenever task is done (reference trigger fired)
  //DAQmxErrChk( "nidaqTest:datapos"      , DAQmxSetReadRelativeTo(dataTask, DAQmx_Val_CurrReadPos) );
  //DAQmxErrChk( "nidaqTest:dataevent"    , DAQmxRegisterDoneEvent(dataTask, 0, recordData, NULL) );
  //DAQmxErrChk( "nidaqTest:dataoffset"   , DAQmxSetReadOffset(dataTask, 0) );
  //DAQmxErrChk( "nidaqTest:dataevent"    , DAQmxRegisterEveryNSamplesEvent(dataTask, DAQmx_Val_Acquired_Into_Buffer, BUFFER_RECV, 0, recordData, NULL) );

  //         This task should be committed to improve performance in software re-triggering
  DAQmxErrChk( "nidaqTest:datacommit"   , DAQmxTaskControl(dataTask, DAQmx_Val_Task_Commit) );
  
  
  //uInt32    numChannels;
  //DAQmxGetReadNumChans(dataTask, &numChannels);


  //---------------------------------------------------------------------------
  //  Send
  //---------------------------------------------------------------------------

  const char                    timebase[]  = "80MHzTimebase";
  const float                   halfPeriod  = 80e6 / dataRate / 2;
  //const char                    timebase[]  = "10MHzRefClock";
  //const float                   halfPeriod  = 80e6 / dataRate / 2;

  // TASK :  Use counter as digital sample clock
  DAQmxErrChk( "nidaqTest:sendclock"    , DAQmxCreateTask("counter", &sendClock) );
  sprintf(channel, "Dev%d/ctr%d", device, sendCounter);
  DAQmxErrChk( "nidaqTest:counter"      ,  DAQmxCreateCOPulseChanTicks( sendClock
                                                                      , channel, "", timebase
                                                                      , DAQmx_Val_Low, 0, halfPeriod, halfPeriod
                                                                      ) );
  DAQmxErrChk( "nidaqTest:countercfg"   , DAQmxCfgImplicitTiming(sendClock, DAQmx_Val_ContSamps, 1) );


  // TASK :  Digital communications task
  DAQmxErrChk( "nidaqTest:sendtask"     , DAQmxCreateTask("send", &sendTask) );

  //         Use CLK and DTA lines for output
  sprintf(channel                       , "Dev%d/port%d/line%d", device, port, sTRGline);
  DAQmxErrChk( "nidaqTest:sendTRG"      , DAQmxCreateDOChan(sendTask, channel, "TRG", DAQmx_Val_ChanPerLine));
  sprintf(channel                       , "Dev%d/port%d/line%d", device, port, sCLKline);
  DAQmxErrChk( "nidaqTest:sendCLK"      , DAQmxCreateDOChan(sendTask, channel, "CLK", DAQmx_Val_ChanPerLine));
  sprintf(channel                       , "Dev%d/port%d/line%d", device, port, sDTAline);
  DAQmxErrChk( "nidaqTest:sendDTA"      , DAQmxCreateDOChan(sendTask, channel, "DTA", DAQmx_Val_ChanPerLine));

  //         Use sample clock to time digital output
  sprintf(channel                       , "/Dev%d/Ctr%dInternalOutput", device, sendCounter);
  DAQmxErrChk( "nidaqTest:sendsampling" , DAQmxCfgSampClkTiming(sendTask, channel, dataRate, DAQmx_Val_Rising, DAQmx_Val_FiniteSamps, BUFFER_SEND) );

  //         Use onboard circular buffer and transfer data when half empty
  //DAQmxErrChk( "nidaqTest:sendregen"    , DAQmxSetWriteRegenMode(sendTask, DAQmx_Val_AllowRegen) );
  DAQmxErrChk( "nidaqTest:sendregen"    , DAQmxSetWriteRegenMode(sendTask, DAQmx_Val_DoNotAllowRegen) );
  DAQmxErrChk( "nidaqTest:sendxfer"     , DAQmxSetDODataXferReqCond(sendTask, "", DAQmx_Val_OnBrdMemHalfFullOrLess) ); 
  //DAQmxErrChk( "nidaqTest:sendnsamples" , DAQmxRegisterEveryNSamplesEvent(sendTask, DAQmx_Val_Transferred_From_Buffer, BUFFER_SEND, 0, &regenerateData, NULL) );

  //         Configure length of RAM buffer
  DAQmxErrChk( "nidaqTest:outbuffer"    , DAQmxCfgOutputBuffer(sendTask, BUFFER_SEND) );
  //DAQmxErrChk( "nidaqTest:outpos"       , DAQmxSetWriteRelativeTo(sendTask, DAQmx_Val_CurrWritePos) );
  //DAQmxErrChk( "nidaqTest:outoffset"    , DAQmxSetWriteOffset(sendTask, 5) );

  //         This task should be committed to improve performance in software restart
  DAQmxErrChk( "nidaqTest:sendcommit"   , DAQmxTaskControl(sendTask, DAQmx_Val_Task_Commit) );



  //---------------------------------------------------------------------------

  // Turn off Matlab memory management
  mexAtExit(&cleanup);

  // Initialize all bits 
  uInt8*                      nTRG          = NOTHING;
  uInt8*                      nCLK          = NOTHING +   BUFFER_SEND;
  uInt8*                      nDTA          = NOTHING + 2*BUFFER_SEND;
  for (size_t oBit = 0; oBit < BUFFER_SEND; ++oBit) {
    sTRG[oBit]  = nTRG[oBit]  = 0;
    sCLK[oBit]  = nCLK[oBit]  = 0;
    sDTA[oBit]  = nDTA[oBit]  = 1;
  }
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
    mexNargChk ("nidaqTest:init", 9, 0);

    // Setup NI-DAQ lines
    initialize( static_cast<int>( mxGetScalar(prhs[1]) )
              , static_cast<int>( mxGetScalar(prhs[2]) )
              , static_cast<int>( mxGetScalar(prhs[3]) )
              , static_cast<int>( mxGetScalar(prhs[4]) )
              , static_cast<int>( mxGetScalar(prhs[5]) )
              , static_cast<int>( mxGetScalar(prhs[6]) )
              , static_cast<int>( mxGetScalar(prhs[7]) )
              , static_cast<int>( mxGetScalar(prhs[8]) )
              , static_cast<int>( mxGetScalar(prhs[9]) )
              );

    // Start tasks in order of dependencies
    DAQmxErrChk( "nidaqTest:datastart"    , DAQmxStartTask(dataTask  ) );
    DAQmxErrChk( "nidaqTest:samplestart"  , DAQmxStartTask(sendClock ) );

    std::thread               receiveThread(recordData);
    receiveThread.detach();
  }

  //----- Send mode
  else if (std::strcmp(command, "send") == 0) {
    mexNargChk  ("nidaqTest:send", 2, 0);
    mexInitCheck();

    const int         numBytes      = mxGetNumberOfElements(prhs[1]);
    const uInt8*      matBytes      = (const uInt8*) mxGetData(prhs[1]);
    if (mxGetScalar(prhs[2]) > 0)
      transmitData(numBytes, matBytes);
    else {
      if (numBytes > MAX_SEND)
        mexErrMsgIdAndTxt("nidaqTest:overflow", "Cannot send more than %d bytes in background; data was %d bytes.", MAX_SEND, numBytes);

      std::copy(matBytes, matBytes + numBytes, sendCache);
      std::thread     sendThread(transmitData, numBytes, sendCache);
      sendThread.detach();
    }
  }

  //----- Receive mode
  else if (std::strcmp(command, "receive") == 0) {
    mexNargChk  ("nidaqTest:receive", 1, 2);
    mexInitCheck();

    // Wait until a packet is received
    const std::chrono::milliseconds   
      maxWaitMSec     = std::chrono::milliseconds(static_cast<long long>(1000 * mxGetScalar(prhs[1])));
    const int         maxWaitIters  = static_cast<int>( maxWaitMSec / T_SLEEP );
    for (int iWait = 0; iWait < maxWaitIters; ++iWait) {
      if (packetSize > 0)           break;
      std::this_thread::sleep_for(T_SLEEP);
    }

    // Create Matlab return values
    plhs[0]           = mxCreateStringFromNChars(recvBuffer, packetSize);
    plhs[1]           = mxCreateDoubleScalar(packetTime);
  }

  //----- Cleanup mode
  else if (std::strcmp(command, "end") == 0) {
    mexNargChk("nidaqTest:end", 0, 0);
    cleanup();
  }

  //----- Reset device
  else if (std::strcmp(command, "reset") == 0) {
    mexNargChk("nidaqTest:end", 1, 0);
    cleanup();
    resetDAQ(mxGetScalar(prhs[1]));
  }

  //----- Unsupported command
  else  mexUsageError();
}
