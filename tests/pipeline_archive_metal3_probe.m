#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <stdio.h>
#include <stdlib.h>
#include "games/totk/third_party/d2r_gfx/gfx/nvn/nvn_archive_map.h"

static int fail(const char *where, NSError *error) {
    fprintf(stderr, "FAIL %s: %s\n", where, error.localizedDescription.UTF8String ?: "unknown Metal error");
    return 1;
}

int main(void) {
    @autoreleasepool {
        id<MTLDevice> dev = MTLCreateSystemDefaultDevice();
        if (!dev) { puts("no Metal device"); return 77; }

        NSString *source =
            @"#include <metal_stdlib>\n"
             @"using namespace metal;\n"
             @"vertex float4 archive_vertex(uint id [[vertex_id]]) {\n"
             @"  float2 p = float2((id == 1) ? 3.0f : -1.0f, (id == 2) ? 3.0f : -1.0f);\n"
             @"  return float4(p, 0.0f, 1.0f);\n"
             @"}\n"
             @"fragment float4 archive_fragment() { return float4(1.0f); }\n"
             @"kernel void archive_compute(device uint *out [[buffer(0)]], uint id [[thread_position_in_grid]]) { out[id] = id; }\n";
        NSError *error = nil;
        id<MTLLibrary> library = [dev newLibraryWithSource:source options:nil error:&error];
        if (!library) return fail("compile Metal 3 probe shader", error);
        id<MTLFunction> vertex = [library newFunctionWithName:@"archive_vertex"];
        id<MTLFunction> fragment = [library newFunctionWithName:@"archive_fragment"];
        id<MTLFunction> compute = [library newFunctionWithName:@"archive_compute"];
        if (!vertex || !fragment || !compute) return fail("resolve probe functions", nil);

        MTLRenderPipelineDescriptor *render = [MTLRenderPipelineDescriptor new];
        render.vertexFunction = vertex;
        render.fragmentFunction = fragment;
        render.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;

        MTLComputePipelineDescriptor *computeDesc = [MTLComputePipelineDescriptor new];
        computeDesc.computeFunction = compute;

        NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:
                          [NSString stringWithFormat:@"m3-pipeline-%@.metalarchive", NSUUID.UUID.UUIDString]];
        NSURL *url = [NSURL fileURLWithPath:path];
        MTLBinaryArchiveDescriptor *writeDesc = [MTLBinaryArchiveDescriptor new];
        id<MTLBinaryArchive> writer = [dev newBinaryArchiveWithDescriptor:writeDesc error:&error];
        if (!writer) return fail("create Metal 3 binary archive", error);
        if (![writer addRenderPipelineFunctionsWithDescriptor:render error:&error])
            return fail("add render functions to archive", error);
        if (![writer addComputePipelineFunctionsWithDescriptor:computeDesc error:&error])
            return fail("add compute functions to archive", error);
        if (![writer serializeToURL:url error:&error])
            return fail("serialize Metal 3 binary archive", error);

        MTLBinaryArchiveDescriptor *readDesc = [MTLBinaryArchiveDescriptor new];
        readDesc.url = url;
        uint64_t mappedBefore = arch_map_count();
        arch_map_begin();
        id<MTLBinaryArchive> reader = [dev newBinaryArchiveWithDescriptor:readDesc error:&error];
        arch_map_end();
        if (!reader) return fail("reopen Metal 3 binary archive", error);
        if (arch_map_count() == mappedBefore)
            puts("note: Metal did not call the NSData archive-map hook on this OS build");

        render.binaryArchives = @[reader];
        id<MTLRenderPipelineState> renderPSO =
            [dev newRenderPipelineStateWithDescriptor:render
                                               options:MTLPipelineOptionFailOnBinaryArchiveMiss
                                            reflection:nil
                                                 error:&error];
        if (!renderPSO) return fail("load render pipeline from Metal 3 archive", error);

        computeDesc.binaryArchives = @[reader];
        id<MTLComputePipelineState> computePSO =
            [dev newComputePipelineStateWithDescriptor:computeDesc
                                                options:MTLPipelineOptionFailOnBinaryArchiveMiss
                                             reflection:nil
                                                  error:&error];
        if (!computePSO) return fail("load compute pipeline from Metal 3 archive", error);

        [NSFileManager.defaultManager removeItemAtURL:url error:nil];
        puts("Metal 3 binary archive render+compute ok");
    }
    return 0;
}
