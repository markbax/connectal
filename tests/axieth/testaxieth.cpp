
#include <AxiEthTestIndication.h>
#include <AxiEthTestRequest.h>

class AxiEthTestIndication : public AxiEthTestIndicationWrapper
{
  sem_t sem;
public:
    uint32_t buf[16];
    virtual void resetDone() {
	fprintf(stderr, "reset done\n");
	sem_post(&sem);
    }
    void wait() {
	sem_wait(&sem);
    }

    void readDone ( const uint32_t value ) {
	buf[0] = value;
	fprintf(stderr, "readDone value=%08x\n", value);
	sem_post(&sem);
    }

    void writeDone (  ) {
	sem_post(&sem);
    }

    AxiEthTestIndication(unsigned int id) : AxiEthTestIndicationWrapper(id) {
      sem_init(&sem, 0, 0);
    }
};


AxiEthTestRequestProxy *request;
AxiEthTestIndication *indication;

int main(int argc, const char **argv)
{
    request = new AxiEthTestRequestProxy(IfcNames_AxiEthTestRequestS2H);
    indication = new AxiEthTestIndication(IfcNames_AxiEthTestIndicationH2S);
    fprintf(stderr, "Reading ID register\n");
    request->read((1<<18) + 0x4f8);
    indication->wait();
    return 0;
}

