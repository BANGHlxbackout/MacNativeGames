#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>
#include DIRTY_C

void dm_fault_hook_register(int (*fn)(void *, int, void *)) { (void)fn; }
void dm_guest_write_prep_register(void (*fn)(void *, size_t)) { (void)fn; }

int main(void) {
    size_t pg = (size_t)getpagesize(), size = pg * 256;
    void *mem = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
    if (mem == MAP_FAILED) return 2;
    nvn_dirty_add_range(mem, size);
    uint64_t stamp = nvn_dirty_now();
    nvn_dirty_protect(mem, size);
    if (!on_fault((char *)mem + pg * 130, 1, NULL)) return 3;
    if (nvn_dirty_since(mem, pg, stamp)) return 4;
    if (!nvn_dirty_since((char *)mem + pg * 130, pg, stamp)) return 5;
    uint64_t hit=0, miss=0, skip=0, scan=0;
    nvn_dirty_fast_stats(&hit, &miss, &skip, &scan);
    if (!skip || !scan) { fprintf(stderr, "no block fast path: skip=%llu scan=%llu\n",
                                  (unsigned long long)skip, (unsigned long long)scan); return 6; }
    puts("dirty fast path ok");
    munmap(mem, size);
    return 0;
}
