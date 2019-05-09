#include <mex.h>
#include <cmath>
#include <algorithm>



//=============================================================================
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
  // Hard-coded constants
  static const size_t   NCOMMBITS       = 8;
  static const size_t   NADDRBITS       = 7;
  static const unsigned char    ONE     = 1;

  // HACK:  Bit mask for big- vs. small-endian encoding, hard coded for speed
  static const unsigned char    MASK[2][8]
                                        = { { (ONE << 7), (ONE << 6), (ONE << 5), (ONE << 4), (ONE << 3), (ONE << 2), (ONE << 1), (ONE << 0) }
                                          , { (ONE << 0), (ONE << 1), (ONE << 2), (ONE << 3), (ONE << 4), (ONE << 5), (ONE << 6), (ONE << 7) }
                                          };


  //---------------------------------------------------------------------------

  // Check inputs to mex function
  if (nlhs != 1 || nrhs < 2 || nrhs > 3)
    mexErrMsgIdAndTxt ( "bitbangI2C:usage", "bitstream = bitbangI2C(data, isBigEndian, [dataTypeBits = 64])" );

  const unsigned char*  data            = (unsigned char*) mxGetData(prhs[0]);
  const bool            isBigEndian     = ( mxGetScalar(prhs[1]) > 0 );
  const size_t          nDatumBits      = ( nlhs > 2 ? static_cast<size_t>(mxGetScalar(prhs[2])) : 64 );
  const size_t          numBytes        = mxGetNumberOfElements(prhs[0]) * nDatumBits / NCOMMBITS;


  // Create output structure
  const size_t          nPacketBits     = 2                             // START
                                        + 2*(NADDRBITS + 2)             // address + R/W + ACK
                                        + (3*NCOMMBITS + 3)*numBytes    // data byte + ACK
                                        + 4                             // STOP
                                        ;
  plhs[0]               = mxCreateDoubleMatrix( nPacketBits, 2, mxREAL );
  double*               bitStream       = mxGetPr(plhs[0]);
  double*               sCLK            = bitStream;
  double*               sDTA            = bitStream + nPacketBits;


  //---------------------------------------------------------------------------

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

  // DATA
  const unsigned char*  bitMask         = MASK[isBigEndian];
  for (size_t iByte = 0; iByte < numBytes; ++iByte) {
    for (size_t jBit = 0; jBit < NCOMMBITS; ++jBit) {
      const bool        dataBit         = data[iByte] & bitMask[jBit];
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

}
