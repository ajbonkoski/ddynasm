module ddynasm.dasm_x86;

import std.string;
import std.exception;
import core.sys.posix.sys.mman;
import core.stdc.string;

enum DASM_IDENT = "DynASM 1.3.0";
enum DASM_VERSION = 10300;   /* 1.3.0 */

enum DASM_S_OK         = 0x00000000;
enum DASM_S_NOMEM      = 0x01000000;
enum DASM_S_PHASE      = 0x02000000;
enum DASM_S_MATCH_SEC  = 0x03000000;
enum DASM_S_RANGE_I    = 0x11000000;
enum DASM_S_RANGE_SEC  = 0x12000000;
enum DASM_S_RANGE_LG   = 0x13000000;
enum DASM_S_RANGE_PC   = 0x14000000;
enum DASM_S_RANGE_VREG = 0x15000000;
enum DASM_S_UNDEF_L    = 0x21000000;
enum DASM_S_UNDEF_PC   = 0x22000000;

// using a struct to emulate namespacing
struct Dasm
{
  // C: dasm internal state
  dasm_State *state;

  // allocated mem for JIT'd function
  size_t size = 0;
  char *mem = null;

  void init(int maxsection)
  { dasm_init(&state, maxsection); }

  void free()
  {
    int status = munmap(mem, size);
    assert(status == 0);
    dasm_free(&state);
  }

  /* Setup global array. Must be called before dasm_setup(). */
  void setupglobal(void **gl, uint maxgl)
  { dasm_setupglobal(&state, gl, maxgl); }

  /* Grow PC label array. Can be called after dasm_setup(), too. */
  void growpc(uint maxpc)
  { dasm_growpc(&state, maxpc); }

  /* Setup encoder. */
  void setup(const byte[] actionlist)
  { dasm_setup(&state, actionlist.ptr); }

  /* Link sections and return the resulting size. */
  int link(size_t *szp)
  { return dasm_link(&state, szp); }

  /* Encode sections into buffer. */
  int encode(void *buffer)
  { return dasm_encode(&state, buffer); }

  int function(void*) link_and_encode()
  {
    assert(mem is null);
    int status = this.link(&this.size);
    enforce(status == DASM_S_OK);

    mem = cast(char *) mmap(null, size,
                            PROT_READ | PROT_WRITE,
                            MAP_ANON | MAP_PRIVATE, -1, 0);
    enforce(mem != MAP_FAILED);

    this.encode(mem);
    int success = mprotect(mem, size, PROT_EXEC | PROT_READ);
    assert(success == 0);
    return cast(int function(void*))mem;
  }

  /* Get PC label offset. */
  int getpclabel(uint pc)
  { return dasm_getpclabel(&state, pc); }

}

// mixin helper
string DasmDecl(string varname)
{
  return "Dasm %s;auto Dst = &%s.state;".format(varname, varname);
}

extern(C):

/* Internal DynASM data structures. */
alias const byte *dasm_ActList;

/* Per-section structure. */
struct dasm_Section {
  int *rbuf;		/* Biased buffer pointer (negative section bias). */
  int *buf;		/* True buffer pointer. */
  size_t bsize;		/* Buffer size in bytes. */
  int pos;		/* Biased buffer position. */
  int epos;		/* End of biased buffer position - max single put. */
  int ofs;		/* Byte offset into section. */
}

/* Core structure holding the DynASM encoding state. */
struct dasm_State {
  size_t psize;			/* Allocated size of this structure. */
  dasm_ActList actionlist;	/* Current actionlist pointer. */
  int *lglabels;		/* Local/global chain/pos ptrs. */
  size_t lgsize;
  int *pclabels;		/* PC label chains/pos ptrs. */
  size_t pcsize;
  void **globals;		/* Array of globals (bias -10). */
  dasm_Section *section;	/* Pointer to active section. */
  size_t codesize;		/* Total size of all code sections. */
  int maxsection;		/* 0 <= sectionidx < maxsection. */
  int status;			/* Status code. */
  dasm_Section sections[1];	/* All sections. Alloc-extended. */
};

/* Initialize and free DynASM state. */
void dasm_init(dasm_State **Dst, int maxsection);
void dasm_free(dasm_State **Dst);

/* Setup global array. Must be called before dasm_setup(). */
void dasm_setupglobal(dasm_State **Dst, void **gl, uint maxgl);

/* Grow PC label array. Can be called after dasm_setup(), too. */
void dasm_growpc(dasm_State **Dst, uint maxpc);

/* Setup encoder. */
void dasm_setup(dasm_State **Dst, const void *actionlist);

/* Feed encoder with actions. Calls are generated by pre-processor. */
void dasm_put(dasm_State **Dst, int start, ...);

/* Link sections and return the resulting size. */
int dasm_link(dasm_State **Dst, size_t *szp);

/* Encode sections into buffer. */
int dasm_encode(dasm_State **Dst, void *buffer);

/* Get PC label offset. */
int dasm_getpclabel(dasm_State **Dst, uint pc);


// #ifdef DASM_CHECKS
// /* Optional sanity checker to call between isolated encoding steps. */
// DASM_FDEF int dasm_checkstep(dasm_State **Dst, int secmatch);
// #else
// #define dasm_checkstep(a, b)	0
// #endif

