#import <Metal/Metal.h>
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <stdatomic.h>
#include <dispatch/dispatch.h>
#include <CoreFoundation/CoreFoundation.h>
#include <objc/runtime.h>
#include <time.h>

static id<MTLDevice> g_dev;
static void res_add_stub(id<MTLResource> r) { (void)r; }
static void res_remove_stub(id<MTLResource> r) { (void)r; }
static void res_commit(void) {}
#define res_add(r) res_add_stub((id<MTLResource>)(r))
#define res_remove(r) res_remove_stub((id<MTLResource>)(r))
#define MLOG(...) do { fprintf(stderr, "[heap-test] "); fprintf(stderr, __VA_ARGS__); fputc('\n', stderr); } while (0)
static void retire_idle_kick(void);
#include "games/totk/third_party/d2r_gfx/gfx/nvn/nvn_heap_cache.h"
static void retire_idle_kick(void) {
    rt_heap_trim_at(clock_gettime_nsec_np(CLOCK_UPTIME_RAW), 0);
    res_commit();
}

int main(void) {
    @autoreleasepool {
        setenv("TOTK_HEAP_REUSE", "1", 1);
        g_dev = MTLCreateSystemDefaultDevice();
        if (!g_dev) { puts("no Metal device"); return 77; }
        MTLTextureDescriptor *d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
                                                                                       width:256 height:256 mipmapped:YES];
        d.storageMode = MTLStorageModePrivate;
        d.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;
        void *heap = NULL;
        @autoreleasepool {
            id<MTLTexture> first = rt_heap_texture(d);
            if (!first || !first.heap) { fprintf(stderr, "first heap allocation failed\n"); return 1; }
            heap = (__bridge void *)first.heap;
        }
        if (g_rt_heap_n != 1) { fprintf(stderr, "heap was not cached: %d\n", g_rt_heap_n); return 2; }
        @autoreleasepool {
            id<MTLTexture> second = rt_heap_texture(d);
            if (!second || (__bridge void *)second.heap != heap || !g_rt_heap_reused) {
                fprintf(stderr, "heap was not reused: n=%d reused=%llu\n", g_rt_heap_n, (unsigned long long)g_rt_heap_reused);
                return 3;
            }
        }
        rt_heap_trim_at(clock_gettime_nsec_np(CLOCK_UPTIME_RAW) + RT_HEAP_IDLE_NS + 1, 0);
        if (g_rt_heap_n != 0) { fprintf(stderr, "expired heap remains: %d\n", g_rt_heap_n); return 4; }
        puts("Metal 3 heap reuse ok");
    }
    return 0;
}
