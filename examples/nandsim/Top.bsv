// bsv libraries
import SpecialFIFOs::*;
import Vector::*;
import StmtFSM::*;
import FIFO::*;
import BRAM::*;
import DefaultValue::*;

// portz libraries
import Leds::*;
import AxiMasterSlave::*;
import Directory::*;
import CtrlMux::*;
import Portal::*;
import PortalMemory::*;
import Dma::*;
import AxiDma::*;

// generated by tool
import NandSimRequestWrapper::*;
import DmaConfigWrapper::*;
import NandSimIndicationProxy::*;
import DmaIndicationProxy::*;

// defined by user
import NandSim::*;

module mkPortalTop(StdPortalTop#(addrWidth)) provisos (
    Add#(addrWidth, a__, 52),
    Add#(b__, addrWidth, 64),
    Add#(c__, 12, addrWidth),
    Add#(addrWidth, d__, 44));

   DmaIndicationProxy dmaIndicationProxy <- mkDmaIndicationProxy(9);

   NandSimIndicationProxy nandSimIndicationProxy <- mkNandSimIndicationProxy(7);
   
   BRAM1Port#(Bit#(14), Bit#(64)) br <- mkBRAM1Server(defaultValue);
   NandSim nandSim <- mkNandSim(nandSimIndicationProxy.ifc, br.portA);
   NandSimRequestWrapper nandSimRequestWrapper <- mkNandSimRequestWrapper(1008,nandSim.request);

   Vector#(1, DmaReadClient#(64)) readClients = cons(nandSim.readClient, nil);
   Vector#(1, DmaWriteClient#(64)) writeClients = cons(nandSim.writeClient, nil);
   Integer             numRequests = 2;
   AxiDmaServer#(addrWidth,64) dma <- mkAxiDmaServer(dmaIndicationProxy.ifc, numRequests, readClients, writeClients);

   DmaConfigWrapper dmaRequestWrapper <- mkDmaConfigWrapper(1005,dma.request);

   Vector#(4,StdPortal) portals;
   portals[0] = nandSimRequestWrapper.portalIfc;
   portals[1] = nandSimIndicationProxy.portalIfc; 
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
      
endmodule : mkPortalTop
