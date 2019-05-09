#include <mex.h>
#include <NIDAQmx.h>


#define DAQmxErrChk(errID, functionCall)                    \
    if ( DAQmxFailed(functionCall) ) {                      \
      char                    errBuff[2048] = {'\0'};       \
      DAQmxGetExtendedErrorInfo(errBuff, 2048);             \
      mexErrMsgIdAndTxt(errID, "[%s]  %s", errID, errBuff); \
    }



TaskHandle                    timeTask   = NULL;
//TaskHandle                    time2Task  = NULL;


//=============================================================================
void cleanup()
{
  if (timeTask) {
    DAQmxStopTask (timeTask);
    DAQmxClearTask(timeTask);
  }
  //if (time2Task) {
  //  DAQmxStopTask (time2Task);
  //  DAQmxClearTask(time2Task);
  //}
  timeTask                    = NULL;
  //time2Task                   = NULL;
}


//=============================================================================
void initialize( int device, int port, int counter, int timer )
{
  char                        channel[1000];
  char                        source[1000];

  // (Re-)create tasks
  cleanup();

  // Counter task for use as timestamp
  DAQmxErrChk( "nidaqTime:timetask" , DAQmxCreateTask("timer", &timeTask) );
  sprintf(channel, "Dev%d/ctr%d", device, timer);
  DAQmxErrChk( "nidaqTime:timectr"  , DAQmxCreateCICountEdgesChan(timeTask, channel, "", DAQmx_Val_Rising, 0, DAQmx_Val_CountUp) );
  sprintf(source, "/Dev%d/Ctr%dInternalOutput", device, counter);
  DAQmxErrChk( "nidaqTime:timesrc"  , DAQmxSetCICountEdgesTerm(timeTask, channel, source) );

  //***************** DOES NOT WORK
  //// Test for multiple readouts of the same counter
  //DAQmxErrChk( "nidaqTime2:time2task", DAQmxCreateTask("timer2", &time2Task) );
  //sprintf(channel, "Dev%d/ctr%d", device, timer);
  //DAQmxErrChk( "nidaqTime2:time2ctr" , DAQmxCreateCICountEdgesChan(time2Task, channel, "", DAQmx_Val_Rising, 0, DAQmx_Val_CountUp) );

  // Turn off Matlab memory management
  mexAtExit(&cleanup);
}


//=============================================================================
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
  //----- Parse arguments
  if (nlhs > 1 || (nrhs != 0 && nrhs != 4)) {
    mexErrMsgIdAndTxt ( "nidaqTime:arguments"
                      , "Usage:\n"
                        "   nidaqTime(device, port, counter, timer)\n"
                        "   timestamp = nidaqTime()\n"
                        "   nidaqTime()\n"
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

    DAQmxErrChk( "nidaqTime:timestart", DAQmxStartTask(timeTask) );
  }

  // Cleanup mode
  else if (nlhs == 0)
    cleanup();

  // Ensure that initialization has first been done
  else if (!timeTask)
    mexErrMsgIdAndTxt("nidaqTime:usage", "nidaqTime() must be called in initialization mode before transmitting data.");
  
  else {
    plhs[0]                       = mxCreateNumericMatrix(1, 1, mxUINT32_CLASS, mxREAL);
  	uInt32*                       data      = (uInt32*) mxGetData(plhs[0]);
    DAQmxErrChk( "nidaqTime:read" , DAQmxReadCounterScalarU32(timeTask , 1, data    , NULL) );
    //DAQmxErrChk( "nidaqTime:read2", DAQmxReadCounterScalarU32(time2Task, 1, data + 1, NULL) );
  }
}
