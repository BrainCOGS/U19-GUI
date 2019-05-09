#include <mex.h>
#include <NIDAQmx.h>


#define DAQmxErrChk(errID, functionCall)                    \
    if ( DAQmxFailed(functionCall) ) {                      \
  	  char                    errBuff[2048] = {'\0'};       \
      DAQmxGetExtendedErrorInfo(errBuff, 2048);             \
      mexErrMsgIdAndTxt(errID, "[%s]  %s", errID, errBuff); \
    }



TaskHandle                    counterTask   = NULL;
TaskHandle                    commTask      = NULL;
static const size_t           MAX_SAMPLES   = 100;

uInt8                         values[2 * MAX_SAMPLES];
uInt8*                        sCLK          = values;
uInt8*                        sDTA          = values + MAX_SAMPLES;
size_t                        numRegens     = 0;


//=============================================================================
int32 CVICALLBACK regenerateData(TaskHandle commTask, int32 everyNsamplesEventType, uInt32 nSamples, void *callbackData)
{
  //// Initialize all bits 
  //if (++numRegens % 2) {
  //  for (size_t iBit = 0; iBit < MAX_SAMPLES; ++iBit)
  //    sDTA[iBit]              = (iBit / 2) % 2;
  //} else {
  //  for (size_t iBit = 0; iBit < MAX_SAMPLES; ++iBit)
  //    sDTA[iBit]              = (iBit < MAX_SAMPLES/2);
  //}

  int32                       error         = DAQmxWriteDigitalLines( commTask, MAX_SAMPLES
                                                                    , false, 1, DAQmx_Val_GroupByChannel
                                                                    , values, 0, NULL
                                                                    );
  return error;
}

//=============================================================================
void setData(uInt32 x)
{
  size_t                      iBit          = 0;
  for (; iBit < 32; ++iBit)
    sDTA[iBit]                = (x & (1 << iBit)) > 0;
  for (; iBit < MAX_SAMPLES; ++iBit)
    sDTA[iBit]                = 1;

  DAQmxErrChk( "nidaqComm:write", DAQmxWriteDigitalLines( commTask, MAX_SAMPLES
                                                        , false, 1, DAQmx_Val_GroupByChannel
                                                        , values, 0, NULL
                                                        ) );

  for (size_t iBit = 0; iBit < MAX_SAMPLES; ++iBit)
    sDTA[iBit]                = (iBit / 2) % 2;
  DAQmxErrChk( "nidaqComm:write", DAQmxWriteDigitalLines( commTask, MAX_SAMPLES
                                                        , false, 1, DAQmx_Val_GroupByChannel
                                                        , values, 0, NULL
                                                        ) );
}


//=============================================================================
void cleanup()
{
  if (counterTask) {
    DAQmxStopTask (counterTask);
    DAQmxClearTask(counterTask);
  }
  if (commTask) {
    DAQmxWaitUntilTaskDone(commTask, 1);
    DAQmxStopTask         (commTask);
    DAQmxClearTask        (commTask);
  }

  counterTask                 = NULL;
  commTask                    = NULL;
  numRegens                   = 0;
}


//=============================================================================
void initialize( int device, int port, int lineCLK, int lineDTA, int counter = 0 )
{
  char                        channel[1000];

  // (Re-)create tasks
  cleanup();

  // Counter task for use as digital sample clock
  DAQmxErrChk( "nidaqSend:countertask", DAQmxCreateTask("counter", &counterTask) );
  sprintf(channel, "Dev%d/ctr%d", device, counter);
  DAQmxErrChk( "nidaqSend:counter",  DAQmxCreateCOPulseChanTicks( counterTask
                                                                , channel, "", "10MHzRefClock"
                                                                , DAQmx_Val_Low, 0, 5000, 5000
                                                                ) );
  DAQmxErrChk( "nidaqComm:countercfg"   , DAQmxCfgImplicitTiming(counterTask, DAQmx_Val_ContSamps, 1) );
  DAQmxErrChk( "nidaqSend:counterstart" , DAQmxStartTask(counterTask) );

  // Digital communications task
  DAQmxErrChk( "nidaqSend:commtask"     , DAQmxCreateTask("comm", &commTask) );
  sprintf(channel                       , "Dev%d/port%d/line%d", device, port, lineCLK);
  DAQmxErrChk( "nidaqSend:commCLK"      , DAQmxCreateDOChan(commTask, channel, "CLK", DAQmx_Val_ChanPerLine));
  sprintf(channel                       , "Dev%d/port%d/line%d", device, port, lineDTA);
  DAQmxErrChk( "nidaqSend:commDTA"      , DAQmxCreateDOChan(commTask, channel, "DTA", DAQmx_Val_ChanPerLine));
  sprintf(channel                       , "/Dev%d/Ctr%dInternalOutput", device, counter);
  DAQmxErrChk( "nidaqSend:commsampling" , DAQmxCfgSampClkTiming(commTask, channel, 1e3, DAQmx_Val_Rising, DAQmx_Val_ContSamps, MAX_SAMPLES) );
  DAQmxErrChk( "nidaqSend:commregen"    , DAQmxSetWriteRegenMode(commTask, DAQmx_Val_AllowRegen) );
  //DAQmxErrChk( "nidaqSend:commregen"    , DAQmxSetWriteRegenMode(commTask, DAQmx_Val_DoNotAllowRegen) );

  //DAQmxErrChk( "nidaqSend:brdmem"       , DAQmxSetDOUseOnlyOnBrdMem(commTask, "", true) );

  //DAQmxErrChk( "nidaqSend:xferDTA"      , DAQmxSetDODataXferReqCond(commTask, "", DAQmx_Val_OnBrdMemEmpty) );
  DAQmxErrChk( "nidaqSend:xferDTA"      , DAQmxSetDODataXferReqCond(commTask, "", DAQmx_Val_OnBrdMemHalfFullOrLess) ); 
  //DAQmxErrChk( "nidaqSend:nsamples"     , DAQmxRegisterEveryNSamplesEvent(commTask, DAQmx_Val_Transferred_From_Buffer, MAX_SAMPLES, 0, &regenerateData, values) );

  // Turn off Matlab memory management
  mexAtExit(&cleanup);

  DAQmxErrChk( "nidaqSend:outbuffer"    , DAQmxCfgOutputBuffer(commTask, MAX_SAMPLES) );
  //DAQmxErrChk( "nidaqSend:outpos"       , DAQmxSetWriteRelativeTo(commTask, DAQmx_Val_CurrWritePos) );
  //DAQmxErrChk( "nidaqSend:outoffset"    , DAQmxSetWriteOffset(commTask, 5) );

  uInt32    bufferSize;
  DAQmxGetBufOutputBufSize(commTask, &bufferSize);
  mexPrintf("Buffer size         : %d\n", bufferSize);
  DAQmxGetBufOutputOnbrdBufSize(commTask, &bufferSize);
  mexPrintf("Onboard buffer size : %d\n", bufferSize);


  //---------------------------------------------------------------------------

  // Initialize all bits 
  for (size_t iBit = 0; iBit < MAX_SAMPLES; ++iBit) {
    sCLK[iBit]                = iBit % 2;
    sDTA[iBit]                = (iBit / 2) % 2;
  }
}


//=============================================================================
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
  //----- Parse arguments
  if (nlhs > 1 || (nrhs != 0 && nrhs != 1 && nrhs != 4)) {
    mexErrMsgIdAndTxt ( "nidaqSend:arguments"
                      , "Usage:\n"
                        "   nidaqSend(device, port, lineCLK, lineDTA)\n"
                        "   samplesWritten = nidaqSend(data)\n"
                        "   nidaqSend()\n"
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

    DAQmxErrChk( "nidaqComm:write"    , DAQmxWriteDigitalLines( commTask, MAX_SAMPLES
                                                              , false, 0, DAQmx_Val_GroupByChannel
                                                              , values, &samplesWritten, NULL
                                                              ) );
    DAQmxErrChk( "nidaqSend:commstart" , DAQmxStartTask(commTask) );
  }

  // Cleanup mode
  else if (nrhs == 0)
    cleanup();

  // Ensure that initialization has first been done
  else if (!commTask || !counterTask)
    mexErrMsgIdAndTxt("nidaqSend:usage", "nidaqSend() must be called in initialization mode before transmitting data.");
  
  else {
    setData(static_cast<uInt32>(mxGetScalar(prhs[0])));
  }


  // Output number of samples written
  if (nlhs > 0)
    plhs[0]                       = mxCreateDoubleScalar(samplesWritten);
}
