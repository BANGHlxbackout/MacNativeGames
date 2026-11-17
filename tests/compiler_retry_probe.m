#import <Foundation/Foundation.h>
#include <stdio.h>
#include "../games/totk/third_party/d2r_gfx/gfx/nvn/nvn_compiler_retry.h"

static NSError *xpc_error(void) {
    return [NSError errorWithDomain:@"MetalCompiler" code:1
                            userInfo:@{NSLocalizedDescriptionKey: @"XPC_ERROR_CONNECTION_INTERRUPTED"}];
}

int main(void) {
    @autoreleasepool {
        NSError *error = nil;
        int calls = 0;
        BOOL ok = compiler_retry(&error, 0, ^BOOL(NSError **attempt_error) {
            calls++;
            if (calls < 3) { *attempt_error = xpc_error(); return NO; }
            return YES;
        });
        if (!ok || calls != 3 || error) {
            fprintf(stderr, "retry success case: ok=%d calls=%d error=%s\n",
                    ok, calls, error.localizedDescription.UTF8String ?: "-");
            return 1;
        }

        calls = 0;
        ok = compiler_retry(&error, 0, ^BOOL(NSError **attempt_error) {
            calls++;
            *attempt_error = [NSError errorWithDomain:@"MetalCompiler" code:2
                                              userInfo:@{NSLocalizedDescriptionKey: @"ordinary compile error"}];
            return NO;
        });
        if (ok || calls != 1 || !error) {
            fprintf(stderr, "non-XPC error retried: ok=%d calls=%d\n", ok, calls);
            return 2;
        }

        calls = 0;
        ok = compiler_retry(&error, 0, ^BOOL(NSError **attempt_error) {
            calls++; *attempt_error = xpc_error(); return NO;
        });
        if (ok || calls != COMPILER_RETRY_ATTEMPTS || !error) {
            fprintf(stderr, "retry limit wrong: ok=%d calls=%d\n", ok, calls);
            return 3;
        }
        puts("compiler retry policy ok");
    }
    return 0;
}
