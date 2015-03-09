
// Copyright (c) 2014 Quanta Research Cambridge, Inc.

// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.


#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <assert.h>
#include <string.h>
#include <netinet/in.h>

#include "maxsonar_simple.h"
#include "gyro_simple.h"
#include "hbridge_simple.h"
#include "sock_utils.h"

#include "MaxSonarSampleStream.h"
#include "GyroSampleStream.h"
#include "HBridgeCtrlRequest.h"
#include "MaxSonarCtrlRequest.h"
#include "GyroCtrlRequest.h"
#include "GeneratedTypes.h"
#include "StdDmaIndication.h"
#include "MemServerRequest.h"
#include "MMURequest.h"
#include "dmaManager.h"
#include "read_buffer.h"

static int spew = 0;
static int alloc_sz = 1<<10;

void* drive_hbridges(void *_x)
{
  HBridgeCtrlRequestProxy *device = (HBridgeCtrlRequestProxy*)_x;
  sleep(20);

  // for(int i = 0; i < 2; i++){
  //   MOVE_FOREWARD(POWER_5);
  //   sleep(1);
  //   STOP;
    
  //   MOVE_BACKWARD(POWER_5);
  //   sleep(1);
  //   STOP;
    
  //   TURN_RIGHT(POWER_5);
  //   sleep(1);
  //   STOP;
    
  //   TURN_LEFT(POWER_5);
  //   sleep(1);
  //   STOP;

  //   sleep(1);
  // }

  for(int i = 0; i < 30; i++){
    TURN_RIGHT(POWER_4);
    usleep(100000);
    STOP;
    sleep(1);
  }
  STOP;


}

int main(int argc, const char **argv)
{
  HBridgeCtrlIndication *hbridge_ind = new HBridgeCtrlIndication(IfcNames_HBridgeControllerIndication);
  HBridgeCtrlRequestProxy *hbridge_ctrl = new HBridgeCtrlRequestProxy(IfcNames_HBridgeControllerRequest);
  MaxSonarCtrlIndication *maxsonar_ind = new MaxSonarCtrlIndication(IfcNames_MaxSonarControllerIndication);
  MaxSonarCtrlRequestProxy *maxsonar_ctrl = new MaxSonarCtrlRequestProxy(IfcNames_MaxSonarControllerRequest);
  GyroCtrlIndication *gyro_ind = new GyroCtrlIndication(IfcNames_GyroControllerIndication);
  GyroCtrlRequestProxy *gyro_ctrl = new GyroCtrlRequestProxy(IfcNames_GyroControllerRequest);
  MemServerRequestProxy *hostMemServerRequest = new MemServerRequestProxy(IfcNames_HostMemServerRequest);
  MMURequestProxy *dmap = new MMURequestProxy(IfcNames_HostMMURequest);
  DmaManager *dma = new DmaManager(dmap);
  MemServerIndication *hostMemServerIndication = new MemServerIndication(hostMemServerRequest, IfcNames_HostMemServerIndication);
  MMUIndication *hostMMUIndication = new MMUIndication(dma, IfcNames_HostMMUIndication);

  PortalSocketParam param0;
  int rc0 = getaddrinfo("0.0.0.0", "5000", NULL, &param0.addr);
  GyroSampleStreamProxy *gssp = new GyroSampleStreamProxy(IfcNames_GyroSampleStream, &socketfuncResp, &param0, &GyroSampleStreamJsonProxyReq, 1000);

  PortalSocketParam param1;
  int rc1 = getaddrinfo("0.0.0.0", "5001", NULL, &param1.addr);
  MaxSonarSampleStreamProxy *msssp = new MaxSonarSampleStreamProxy(IfcNames_MaxSonarSampleStream, &socketfuncResp, &param1, &MaxSonarSampleStreamJsonProxyReq, 1000);

  portalExec_start();

  int dstAlloc = portalAlloc(alloc_sz);
  char *dstBuffer = (char *)portalMmap(dstAlloc, alloc_sz);
  unsigned int ref_dstAlloc = dma->reference(dstAlloc);

  long req_freq = 100000000; // 100 mHz
  long freq = 0;
  setClockFrequency(0, req_freq, &freq);
  fprintf(stderr, "Requested FCLK[0]=%ld actually %ld\n", req_freq, freq);
  
  // sample has one two-byte component for each axis (x,y,z).  This is to ensure 
  // that the X component always lands in offset 0 when the HW wraps around
  int sample_size = 6;
  int bus_data_width = 8;
  int wrap_limit = alloc_sz-(alloc_sz%(sample_size*bus_data_width)); 
  fprintf(stderr, "wrap_limit:%08x\n", wrap_limit);
  char* snapshot = (char*)malloc(alloc_sz);
  reader* r = new reader();
  //r->verbose = 1;

  // setup gyro registers and dma infra
  setup_registers(gyro_ind,gyro_ctrl, ref_dstAlloc, wrap_limit);  
  maxsonar_ctrl->range_ctrl(0xFFFF);
  int discard = 20;

  // start up the thread to drive the hbridges
  pthread_t threaddata;
  pthread_create(&threaddata, NULL, &drive_hbridges, (void*)hbridge_ctrl);
  
  while(true){
#ifdef BSIM
    sleep(5);
#else
    usleep(50000*2);
#endif
    maxsonar_ctrl->pulse_width();
    sem_wait(&(maxsonar_ind->pulse_width_sem));
    float distance = ((float)maxsonar_ind->useconds)/147.0;

    set_en(gyro_ind,gyro_ctrl, 0);
    int datalen = r->read_circ_buff(wrap_limit, ref_dstAlloc, dstAlloc, dstBuffer, snapshot, gyro_ind->write_addr, gyro_ind->write_wrap_cnt, 6); 
    set_en(gyro_ind,gyro_ctrl, 2);
    
    if (!discard){
      if (spew) fprintf(stderr, "(%d microseconds == %f inches)\n", maxsonar_ind->useconds, distance);
      if (spew) display(snapshot, datalen);
      if(datalen){
	int16_t *ss = (int16_t*)snapshot;
	for(int i = 0; i < datalen/2; i+=3){
	  gssp->sample(ss[i+0], ss[i+1], ss[i+2]);
	  // this is a bit wasteful, but it simplifies test_zedboard_robot.py
	  msssp->sample(maxsonar_ind->useconds);
	}
      }
    } else {
      discard--;
    }
  }
}
