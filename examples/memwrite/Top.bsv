// bsv libraries
import SpecialFIFOs::*;
import Vector::*;
import StmtFSM::*;
import FIFO::*;

// portz libraries
import Leds::*;
import AxiMasterSlave::*;
import Directory::*;
import CtrlMux::*;
import Portal::*;
import PortalMemory::*;
import Dma::*;
import DmaUtils::*;
import AxiDma::*;

// generated by tool
import MemwriteRequestWrapper::*;
import DmaConfigWrapper::*;
import MemwriteIndicationProxy::*;
import DmaIndicationProxy::*;

// defined by user
import Memwrite::*;

module mkPortalTop(StdPortalTop#(addrWidth)) provisos (
    Add#(addrWidth, a__, 52),
    Add#(b__, addrWidth, 64),
    Add#(c__, 12, addrWidth),
    Add#(addrWidth, d__, 44));

   DmaIndicationProxy dmaIndicationProxy <- mkDmaIndicationProxy(9);
   DmaWriteBuffer#(64,16) dma_stream_write_chan <- mkDmaWriteBuffer();

   Vector#(0,  DmaReadClient#(64))   readClients = newVector();
   Vector#(1, DmaWriteClient#(64)) writeClients = newVector();
   writeClients[0] = dma_stream_write_chan.dmaClient;
   Integer               numRequests = 8;
   AxiDmaServer#(addrWidth,64)   dma <- mkAxiDmaServer(dmaIndicationProxy.ifc, numRequests, readClients, writeClients);
   DmaConfigWrapper dmaRequestWrapper <- mkDmaConfigWrapper(1005,dma.request);

   
   MemwriteIndicationProxy memwriteIndicationProxy <- mkMemwriteIndicationProxy(7);
   MemwriteRequest memwriteRequest <- mkMemwriteRequest(memwriteIndicationProxy.ifc, dma_stream_write_chan.dmaServer);
   MemwriteRequestWrapper memwriteRequestWrapper <- mkMemwriteRequestWrapper(1008,memwriteRequest);

   Vector#(4,StdPortal) portals;
   portals[0] = memwriteRequestWrapper.portalIfc;
   portals[1] = memwriteIndicationProxy.portalIfc; 
   portals[2] = dmaRequestWrapper.portalIfc;
   portals[3] = dmaIndicationProxy.portalIfc; 
   
   Directory dir <- mkDirectory(portals);
   Vector#(1,StdPortal) directories;
   directories[0] = dir.portalIfc;
   
   // when constructing ctrl and interrupt muxes, directories must be the first argument
   let ctrl_mux <- mkAxiSlaveMux(directories,portals);
   let interrupt_mux <- mkInterruptMux(portals);
   
   interface interrupt = interrupt_mux;
   interface ctrl = ctrl_mux;
   interface m_axi = dma.m_axi;
   interface leds = default_leds;
endmodule
