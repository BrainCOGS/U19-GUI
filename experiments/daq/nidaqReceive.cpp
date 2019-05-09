#include <mex.h>
#include <NIDAQmx.h>


#define DAQmxErrChk(errID, functionCall)                    \
    if ( DAQmxFailed(functionCall) ) {                      \
      char                    errBuff[2048] = {'\0'};       \
      DAQmxGetExtendedErrorInfo(errBuff, 2048);             \
      mexErrMsgIdAndTxt(errID, "[%s]  %s", errID, errBuff); \
    }



TaskHandle                    startTask     = NULL;
TaskHandle                    stopTask      = NULL;
TaskHandle                    dataTask      = NULL;
static const size_t           NUM_SAMPLES   = 1024;

int32                         nInfoRead     = -1;
int32                         nInfoBytes    = -1;
uInt8                         info[8];

int32                         nDataRead     = -1;
int32                         nDataBytes    = -1;
uInt8                         data[2 * NUM_SAMPLES];

bool                          doAcquire     = false;
uInt32                        packetTime    = 0;


//=============================================================================
int32 CVICALLBACK readData(TaskHandle task, int32 everyNsamplesEventType, uInt32 nSamples, void *callbackData)
{
  int32                       error         = DAQmxReadDigitalLines ( task, NUM_SAMPLES
                                                                    , 1, DAQmx_Val_GroupByChannel
                                                                    , data, 2*NUM_SAMPLES
                                                                    , &nDataRead, &nDataBytes, NULL
                                                                    );
  return error;
}

int32 CVICALLBACK detectPacketStart(TaskHandle task, int32 signalID, void *callbackData)
{
  int32                       error         = DAQmxReadDigitalLines ( task, 4
                                                                    , 0, DAQmx_Val_GroupByChannel
                                                                    , info, 8
                                                                    , &nInfoRead, &nInfoBytes, NULL
                                                                    );
  //if (!DAQmxFailed(error) && nRead > 0 && clockData[0] > 0) {
  //  doAcquire                 = true;
  //  packetTime                = std::time(0);
  //}

  return error;
}


//=============================================================================
void cleanup()
{
  if (startTask) {
    DAQmxStopTask (startTask);
    DAQmxClearTask(startTask);
  }
  if (stopTask) {
    DAQmxStopTask (stopTask);
    DAQmxClearTask(stopTask);
  }
  if (dataTask) {
    DAQmxStopTask (dataTask);
    DAQmxClearTask(dataTask);
  }

  startTask                 = NULL;
  stopTask                  = NULL;
  dataTask                  = NULL;
}


//=============================================================================
void initialize( int device, int port, int lineCLK, int lineDTA, int counter = 0, int timer = 1 )
{
  char                        channel[1000];

  // (Re-)create tasks
  cleanup();

  // Start packet acquisition
  DAQmxErrChk( "nidaqReceive:startTask"     , DAQmxCreateTask("trig", &startTask) );
  sprintf(channel                           , "Dev%d/port%d/line%d", device, port, lineCLK);
  DAQmxErrChk( "nidaqReceive:startCLK"      , DAQmxCreateDIChan(startTask, channel, "CLK", DAQmx_Val_ChanPerLine));
  sprintf(channel, "Dev%d/Ctr%dInternalOutput", device, timer);
  DAQmxErrChk( "nidaqReceive:startTIM"      , DAQmxCreateDIChan(startTask, channel, "TIM", DAQmx_Val_ChanPerLine));
  sprintf(channel                           , "Dev%d/port%d/line%d", device, port, lineDTA);
  DAQmxErrChk( "nidaqReceive:startchange"   , DAQmxCfgChangeDetectionTiming(startTask, channel, "", DAQmx_Val_ContSamps, 1));
  DAQmxErrChk( "nidaqReceive:startevent"    , DAQmxRegisterSignalEvent(startTask, DAQmx_Val_ChangeDetectionEvent, 0, detectPacketStart, NULL) );


  DAQmxErrChk( "nidaqReceive:datatask"      , DAQmxCreateTask("data", &dataTask) );
  sprintf(channel                           , "Dev%d/port%d/line%d", device, port, lineDTA);
  DAQmxErrChk( "nidaqReceive:dataDTA"       , DAQmxCreateDIChan(dataTask, channel, "DTA", DAQmx_Val_ChanPerLine));
  sprintf(channel, "Dev%d/Ctr%dInternalOutput", device, timer);
  DAQmxErrChk( "nidaqReceive:dataTIM"       , DAQmxCreateDIChan(dataTask, channel, "TIM", DAQmx_Val_ChanPerLine));
  DAQmxErrChk( "nidaqReceive:datasampling"  , DAQmxCfgSampClkTiming(dataTask, channel, 1e3, DAQmx_Val_Rising, DAQmx_Val_ContSamps, NUM_SAMPLES) );
  DAQmxErrChk( "nidaqReceive:dataevent"     , DAQmxRegisterEveryNSamplesEvent(dataTask, DAQmx_Val_Acquired_Into_Buffer, NUM_SAMPLES, 0, &readData, NULL) );

  // Turn off Matlab memory management
  mexAtExit(&cleanup);
}


//=============================================================================
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
  //----- Parse arguments
  if ((nlhs != 0 && nlhs != 3) || (nrhs != 0 && nrhs != 1 && nrhs != 4)) {
    mexErrMsgIdAndTxt ( "nidaqReceive:arguments"
                      , "Usage:\n"
                        "   nidaqReceive(device, port, lineCLK, lineDTA)\n"
                        "   [nRead, nBytes, data] = nidaqReceive(dataOrPacket)\n"
                        "   nidaqReceive()\n"
                      );
  }

  int32                           samplesWritten  = -1;

  // Initialization mode
  if (nrhs == 4) {
    initialize( static_cast<int>( mxGetScalar(prhs[0]) )
              , static_cast<int>( mxGetScalar(prhs[1]) )
              , static_cast<int>( mxGetScalar(prhs[2]) )
              , static_cast<int>( mxGetScalar(prhs[3]) )
              );

    DAQmxErrChk( "nidaqReceive:startstart" , DAQmxStartTask(dataTask) );
  }

  // Cleanup mode
  else if (nrhs == 0)
    cleanup();

  // Ensure that initialization has first been done
  else if (!dataTask || !startTask)
    mexErrMsgIdAndTxt("nidaqReceive:usage", "nidaqReceive() must be called in initialization mode before transmitting data.");
  
  else if (mxGetScalar(prhs[0]) > 0) {
    plhs[0]                       = mxCreateDoubleScalar(nDataRead);
    plhs[1]                       = mxCreateDoubleScalar(nDataBytes);
    plhs[2]                       = mxCreateNumericMatrix(NUM_SAMPLES/4, 2, mxUINT32_CLASS, mxREAL);
    
    uInt32*                       target    = (uInt32*) mxGetData(plhs[2]);
    const uInt32*                 source    = (uInt32*) data;
    for (int iDatum = 0; iDatum < NUM_SAMPLES/4; ++iDatum)
      target[iDatum]              = source[iDatum];
  }

  else {
    plhs[0]                       = mxCreateDoubleScalar(nInfoRead);
    plhs[1]                       = mxCreateDoubleScalar(nInfoBytes);
    plhs[2]                       = mxCreateNumericMatrix(4, 2, mxUINT8_CLASS, mxREAL);

    uInt8*                        target    = (uInt8*) mxGetData(plhs[2]);
    for (int iDatum = 0; iDatum < 8; ++iDatum)
      target[iDatum]              = data[iDatum];
  }
}
