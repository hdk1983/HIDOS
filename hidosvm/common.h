#define MEMSIZE8086 1048576

unsigned memr (uint32_t addr);
void memw (uint32_t addr, unsigned value);
unsigned memr2 (uint32_t addr);
uint32_t memr4 (uint32_t addr);
void memw2 (uint32_t addr, unsigned value);
void memw4 (uint32_t addr, uint32_t value);
int conin (uint16_t *in);
int vmio (unsigned addr);
int load (void);
void init_common (int argc, char **argv);
void set_memory (void *m, uint32_t ramsize);
