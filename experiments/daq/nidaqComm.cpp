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
static const size_t           MAX_SAMPLES   = 10000;  // This sets the maximum number of samples that can be output at any one time by this function, and should be suitably low so that the digital output rate limit is observed within the expected rate of communications

uInt8                         values[2 * MAX_SAMPLES];
uInt8*                        sCLK          = values;
uInt8*                        sDTA          = values + 1;
size_t                        startData     = 0;
const unsigned char*          bitMask       = 0;

// Hard-coded constants
static const size_t           NCOMMBITS     = 8;
static const size_t           NADDRBITS     = 7;
static const unsigned char    ONE           = 1;

// HACK:  Bit mask for big- vs. small-endian encoding, hard coded for speed
static const unsigned char    MASK[2][8]    = { { (ONE << 7), (ONE << 6), (ONE << 5), (ONE << 4), (ONE << 3), (ONE << 2), (ONE << 1), (ONE << 0) }
                                              , { (ONE << 0), (ONE << 1), (ONE << 2), (ONE << 3), (ONE << 4), (ONE << 5), (ONE << 6), (ONE << 7) }
                                              };


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
}


//=============================================================================
void initialize( bool isBigEndian, int device, int port, int lineCLK, int lineDTA, double frequency = 1e6, int counter = 0 )
{
  char                        channel[1000];

  // (Re-)create tasks
  cleanup();

  // Counter task for use as digital sample clock
  DAQmxErrChk( "nidaqComm:countertask", DAQmxCreateTask("counter", &counterTask) );
  sprintf(channel, "Dev%d/ctr%d", device, counter);
  DAQmxErrChk( "nidaqComm:counter",  DAQmxCreateCOPulseChanTicks( counterTask
                                                                , channel, "", "10MHzRefClock"
                                                                , DAQmx_Val_Low, 0, 5, 5
                                                                ) );
  DAQmxErrChk( "nidaqComm:countercfg"  , DAQmxCfgImplicitTiming(counterTask, DAQmx_Val_ContSamps, 2) );
  DAQmxErrChk( "nidaqComm:counterstart", DAQmxStartTask(counterTask) );

  // Digital communications task
  DAQmxErrChk( "nidaqComm:commtask" , DAQmxCreateTask("comm", &commTask) );
  sprintf(channel, "Dev%d/port%d/line%d", device, port, lineCLK);
  DAQmxErrChk( "nidaqComm:commCLK", DAQmxCreateDOChan(commTask, channel, "", DAQmx_Val_ChanPerLine));
  sprintf(channel, "Dev%d/port%d/line%d", device, port, lineDTA);
  DAQmxErrChk( "nidaqComm:commDTA", DAQmxCreateDOChan(commTask, channel, "", DAQmx_Val_ChanPerLine));
  sprintf(channel, "/Dev%d/Ctr%dInternalOutput", device, counter);
  DAQmxErrChk( "nidaqComm:commsampling", DAQmxCfgSampClkTiming(commTask, channel, frequency, DAQmx_Val_Rising, DAQmx_Val_FiniteSamps, MAX_SAMPLES) );
  //DAQmxErrChk( "nidaqComm:commregen", DAQmxSetWriteRegenMode(commTask, DAQmx_Val_DoNotAllowRegen) );


  // Turn off Matlab memory management
  //mexMakeMemoryPersistent(counterTask);
  //mexMakeMemoryPersistent(commTask);
  mexAtExit(&cleanup);


  //---------------------------------------------------------------------------

  // Parameters for how data is interpreted and written to output lines
  bitMask                     = MASK[isBigEndian];

  // Initialize all bits to one (idle state)
  for (size_t iBit = 0; iBit < 2*MAX_SAMPLES; ++iBit)
    values[iBit]              = 0;

  // START
  size_t                iBit            = 0;
  sCLK[iBit]            = 1;            sDTA[iBit]    = 1;              ++iBit;
  sCLK[iBit]            = 1;            sDTA[iBit]    = 0;              ++iBit;

  // ADDRESS is currently all zeros
  for (size_t iAdd = 0; iAdd < NADDRBITS; ++iAdd) {
    sCLK[iBit]          = 0;                                            ++iBit;
    sCLK[iBit]          = 1;                                            ++iBit;
  }

  // WRITE (0)
  sCLK[iBit]            = 0;                                            ++iBit;
  sCLK[iBit]            = 1;                                            ++iBit;

  // ACK
  sCLK[iBit]            = 0;                                            ++iBit;
  sCLK[iBit]            = 1;                                            ++iBit;

  // Location to start writing data bits
  startData             = iBit;
}


//=============================================================================
size_t bitbangI2C(const mxArray* dataArray)
{
  // Input parameters
  const unsigned char*  data            = (unsigned char*) mxGetData(dataArray);
  size_t                nDatumBits      = 0;
  switch (mxGetClassID(dataArray))
  {
    case mxDOUBLE_CLASS:
    case mxINT64_CLASS:
    case mxUINT64_CLASS:
      nDatumBits        = 64;           break;

    case mxSINGLE_CLASS:
    case mxINT32_CLASS:
    case mxUINT32_CLASS:
      nDatumBits        = 32;           break;

    case mxINT16_CLASS:
    case mxUINT16_CLASS:
      nDatumBits        = 16;           break;

    case mxCHAR_CLASS:
    case mxINT8_CLASS:
    case mxUINT8_CLASS:
      nDatumBits        = 8;            break;

    case mxLOGICAL_CLASS:
      nDatumBits        = 1;            break;

    default:
      mexErrMsgIdAndTxt("nidaqComm:datatype", "Unsupported data type.");
  }

  const size_t          numBytes        = mxGetNumberOfElements(dataArray) * nDatumBits / NCOMMBITS;
  const size_t          nPacketBits     = 2                             // START
                                        + 2*(NADDRBITS + 2)             // address + R/W + ACK
                                        + (3*NCOMMBITS + 3)*numBytes    // data byte + ACK
                                        + 4                             // STOP
                                        ;
  if (nPacketBits > MAX_SAMPLES)
    mexErrMsgIdAndTxt("nidaqComm:datatoolong", "Number of bits to transmit (%d) exceeds the maximum preallocated number %d.", nPacketBits, MAX_SAMPLES);

  //---------------------------------------------------------------------------

  // DATA
  size_t                iBit            = startData;
  for (size_t iByte = 0; iByte < numBytes; ++iByte) {
    for (size_t jBit = 0; jBit < NCOMMBITS; ++jBit) {
      const bool        dataBit         = (data[iByte] & bitMask[jBit]) > 0;
      sCLK[iBit]        = 0;            sDTA[iBit]    = sDTA[iBit-1];   ++iBit;
      sCLK[iBit]        = 0;            sDTA[iBit]    = dataBit;        ++iBit;
      sCLK[iBit]        = 1;            sDTA[iBit]    = dataBit;        ++iBit;
    } // end loop over bits in byte

    // ACK
    sCLK[iBit]          = 0;            sDTA[iBit]    = sDTA[iBit-1];   ++iBit;
    sCLK[iBit]          = 0;                                            ++iBit;
    sCLK[iBit]          = 1;                                            ++iBit;
  } // end loop over data bytes

  // STOP
  sCLK[iBit]            = 0;            sDTA[iBit]    = sDTA[iBit-1];   ++iBit;
  sCLK[iBit]            = 0;            sDTA[iBit]    = 0;              ++iBit;
  sCLK[iBit]            = 1;            sDTA[iBit]    = 0;              ++iBit;
  sCLK[iBit]            = 1;            sDTA[iBit]    = 1;              ++iBit;

  if (iBit != nPacketBits)
    mexErrMsgIdAndTxt("nidaqComm:sanity", "Mismatch between expected (%d) and actual (%d) number of bits to transmit.", nPacketBits, iBit);
  return iBit;
}


//=============================================================================
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
  //----- Parse arguments
  if (nlhs > 1 || (nrhs != 0 && nrhs != 1 && nrhs != 5)) {
    mexErrMsgIdAndTxt ( "nidaqComm:arguments"
                      , "Usage:\n"
                        "   nidaqComm(isBigEndian, device, port, lineCLK, lineDTA)\n"
                        "   samplesWritten = nidaqComm(data)\n"
                        "   nidaqComm()\n"
                      );
  }

  int32                           samplesWritten  = -1;

  // Initialization mode
  if (nrhs == 5) {
    initialize(                   mxGetScalar(prhs[0]) > 0
              , static_cast<int>( mxGetScalar(prhs[1]) )
              , static_cast<int>( mxGetScalar(prhs[2]) )
              , static_cast<int>( mxGetScalar(prhs[3]) )
              , static_cast<int>( mxGetScalar(prhs[4]) )
              );
  }
  
  // Cleanup mode
  else if (nrhs == 0)
    cleanup();

  // Ensure that initialization has first been done
  else if (!commTask || !counterTask)
    mexErrMsgIdAndTxt("nidaqComm:usage", "nidaqComm() must be called in initialization mode before transmitting data.");
  
  else {
    const size_t                  numSamples    = bitbangI2C(prhs[0]);

    DAQmxErrChk( "nidaqComm:commwait" , DAQmxWaitUntilTaskDone( commTask, 1 ) );
    DAQmxErrChk( "nidaqComm:commstop" , DAQmxStopTask         ( commTask ) );
    //DAQmxErrChk( "nidaqComm:buffercfg", DAQmxCfgOutputBuffer  ( commTask, numSamples ) );
    DAQmxErrChk( "nidaqComm:write"    , DAQmxWriteDigitalLines( commTask, numSamples
                                                              , true, 0, DAQmx_Val_GroupByScanNumber
                                                              , values, &samplesWritten, NULL
                                                              ) );
    //DAQmxErrChk( "nidaqComm:stop"     , DAQmxStopTask(commTask) );
  }


  // Output number of samples written
  if (nlhs > 0)
    plhs[0]                       = mxCreateDoubleScalar(samplesWritten);
}
