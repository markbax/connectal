CONNECTALDIR ?= ../..
INTERFACES = SDIORequest SDIOResponse

BSVFILES = Top.bsv SDIO.bsv
CPPFILES= test_sdio1.cpp
CONNECTALFLAGS += -D PS7EXTENDED -D IMPORT_HOSTIF

PIN_TYPE = TestSDIO1Pins
PIN_TYPE_INCLUDE = SDIO
PINOUT_FILE = pinout.json
PIN_BINDINGS = pmod:pmodd

include $(CONNECTALDIR)/Makefile.connectal
