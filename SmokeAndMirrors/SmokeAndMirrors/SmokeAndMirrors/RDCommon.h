#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "RDMacros.h"

NS_ASSUME_NONNULL_BEGIN

// https://clang.llvm.org/docs/Block-ABI-Apple.html
typedef NS_OPTIONS(int, RDBlockInfoFlags) {
    RDBlockInfoFlagIsNoEscape       = (1 << 23),
    RDBlockInfoFlagNeedsFreeing     = (1 << 24),
    RDBlockInfoFlagHasCopyDispose   = (1 << 25),
    RDBlockInfoFlagHasCPPInvolved   = (1 << 26),
    RDBlockInfoFlagIsGC             = (1 << 27),
    RDBlockInfoFlagIsGlobal         = (1 << 28),
    RDBlockInfoFlagHasStret         = (1 << 29),
    RDBlockInfoFlagHasSignature     = (1 << 30),
};

typedef struct RDBlockDescriptor {
    unsigned long int reserved;
    unsigned long int size;
    void (*copy)(void *dst, void *src);           // if RDBlockInfoFlagHasCopyDispose
    void (*dispose)(void *src);                   // if RDBlockInfoFlagHasCopyDispose
    const char *signature;                        // if RDBlockInfoFlagHasSignature
} RDBlockDescriptor;

typedef struct RDBlockInfo {
    __unsafe_unretained Class isa;
    RDBlockInfoFlags flags;
    int reserved;
    void (*invoke)(void *, ...);
    RDBlockDescriptor *descriptor;
} RDBlockInfo;

typedef NS_ENUM(NSUInteger, RDBlockKind) {
    RDBlockKindGlobal,
    RDBlockKindStack,
    RDBlockKindMalloc,
};

RD_EXTERN RDBlockInfoFlags const RDBlockInfoFlagsRefCountMask;

RD_EXTERN BOOL RDIsBlock(id object);
RD_EXTERN RDBlockInfo *RDGetBlockInfo(id block);

RD_EXTERN RDBlockKind RDBlockInfoGetKind(const RDBlockInfo *blockInfo);
RD_EXTERN const char *RDBlockInfoGetObjcSignature(const RDBlockInfo *blockInfo);
RD_EXTERN void (*RDBlockInfoGetDisposeFunction(const RDBlockInfo *blockInfo))(void *src);
RD_EXTERN void (*RDBlockInfoGetCopyFunction(const RDBlockInfo *blockInfo))(void *dst, void *src);
RD_EXTERN size_t RDBlockInfoGetInstanceSize(const RDBlockInfo *blockInfo);

RD_EXTERN RDBlockKind RDBlockGetKind(id block);
RD_EXTERN const char *_Nullable RDBlockGetObjcSignatureRDBlockGetObjcSignature(id block);
RD_EXTERN void (*RDBlockGetDisposeFunction(id block))(void *src);
RD_EXTERN void (*RDBlockGetCopyFunction(id block))(void *dst, void *src);
RD_EXTERN size_t RDBlockGetSize(id block);

RD_EXTERN NSUInteger RDSelectorArgumentsCount(SEL);
RD_EXTERN long RDRetainCount(id _Nullable value);

NS_ASSUME_NONNULL_END
