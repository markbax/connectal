/* Copyright (c) 2014 Quanta Research Cambridge, Inc
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */
import SpecialFIFOs::*;
import Vector::*;
import StmtFSM::*;
import FIFO::*;
import CtrlMux::*;
import Portal::*;
import HostInterface::*;
import BlueScope::*;
import ConnectalMemory::*;
import MemTypes::*;
import MemServer::*;
import MMU::*;
import MemcpyRequest::*;
import BlueScopeRequest::*;
import MemServerRequest::*;
import MMURequest::*;
import MemcpyIndication::*;
import BlueScopeIndication::*;
import MemServerIndication::*;
import MMUIndication::*;
import Memcpy::*;

`define BluescopeSampleLength 8

typedef enum {MemcpyIndication, MemcpyRequest, HostMemServerIndication, HostMemServerRequest, HostMMURequest, HostMMUIndication, BluescopeIndication, BluescopeRequest} IfcNames deriving (Eq,Bits);

module mkConnectalTop(StdConnectalDmaTop#(PhysAddrWidth));

   BlueScopeIndicationProxy blueScopeIndicationProxy <- mkBlueScopeIndicationProxy(BluescopeIndication);
   BlueScope#(64) bs <- mkBlueScope(`BluescopeSampleLength, blueScopeIndicationProxy.ifc);
   BlueScopeRequestWrapper blueScopeRequestWrapper <- mkBlueScopeRequestWrapper(BluescopeRequest,bs.requestIfc);

   MemcpyIndicationProxy memcpyIndicationProxy <- mkMemcpyIndicationProxy(MemcpyIndication);
   Memcpy memcpy <- mkMemcpyRequest(memcpyIndicationProxy.ifc, bs);
   MemcpyRequestWrapper memcpyRequestWrapper <- mkMemcpyRequestWrapper(MemcpyRequest,memcpy.request);

   Vector#(1,  MemReadClient#(64))   readClients = newVector();
   readClients[0] = memcpy.readClient;
   Vector#(2, MemWriteClient#(64)) writeClients = newVector();
   writeClients[0] = bs.writeClient;
   writeClients[1] = memcpy.writeClient;
   MMUIndicationProxy hostMMUIndicationProxy <- mkMMUIndicationProxy(HostMMUIndication);
   MMU#(PhysAddrWidth) hostMMU <- mkMMU(0, True, hostMMUIndicationProxy.ifc);
   MMURequestWrapper hostMMURequestWrapper <- mkMMURequestWrapper(HostMMURequest, hostMMU.request);

   MemServerIndicationProxy hostMemServerIndicationProxy <- mkMemServerIndicationProxy(HostMemServerIndication);
   MemServer#(PhysAddrWidth,64,1) dma <- mkMemServer(readClients, writeClients, cons(hostMMU,nil), hostMemServerIndicationProxy.ifc);
   MemServerRequestWrapper hostMemServerRequestWrapper <- mkMemServerRequestWrapper(HostMemServerRequest, dma.request);

   Vector#(8,StdPortal) portals;
   portals[0] = memcpyRequestWrapper.portalIfc;
   portals[1] = memcpyIndicationProxy.portalIfc; 
   portals[2] = blueScopeRequestWrapper.portalIfc;
   portals[3] = blueScopeIndicationProxy.portalIfc; 
   portals[4] = hostMemServerRequestWrapper.portalIfc;
   portals[5] = hostMemServerIndicationProxy.portalIfc; 
   portals[6] = hostMMURequestWrapper.portalIfc;
   portals[7] = hostMMUIndicationProxy.portalIfc;
   let ctrl_mux <- mkSlaveMux(portals);
   
   interface interrupt = getInterruptVector(portals);
   interface slave = ctrl_mux;
   interface masters = dma.masters;
endmodule


