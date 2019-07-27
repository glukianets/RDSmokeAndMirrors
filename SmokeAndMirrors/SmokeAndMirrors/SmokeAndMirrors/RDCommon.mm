#import "RDCommon.h"

RD_EXTERN RDBlockInfoFlags const RDBlockInfoFlagsRefCountMask = (RDBlockInfoFlags)0xffff;

RD_EXTERN RDBlockInfo *RDGetBlockInfo(id block) {
    return(__bridge RDBlockInfo *)block;
}

RD_EXTERN RDBlockKind RDBlockInfoGetKind(const RDBlockInfo *blockInfo) {
    if (blockInfo->flags & RDBlockInfoFlagIsGlobal || (uintptr_t)blockInfo->isa == (uintptr_t)_NSConcreteGlobalBlock)
        return RDBlockKindGlobal;
    else if ((uintptr_t)blockInfo->isa == (uintptr_t)_NSConcreteStackBlock)
        return RDBlockKindStack;
    else if (blockInfo->flags & RDBlockInfoFlagNeedsFreeing)
        return RDBlockKindMalloc;
    else
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Incomprehensible block kind" userInfo:nil];
}

RD_EXTERN const char *RDBlockInfoGetObjcSignature(const RDBlockInfo *blockInfo) {
    const char *signature = NULL;

    if (blockInfo->flags & RDBlockInfoFlagHasSignature) {
        const char *signaturePtr = (const char *)blockInfo->descriptor;
        signaturePtr += sizeof(blockInfo->descriptor->reserved);
        signaturePtr += sizeof(blockInfo->descriptor->size);
        
        if (blockInfo->flags & RDBlockInfoFlagHasCopyDispose) {
            signaturePtr += sizeof(blockInfo->descriptor->copy);
            signaturePtr += sizeof(blockInfo->descriptor->dispose);
        }
        
        signature = *(const char **)signaturePtr;
    }
    return signature;
}

RD_EXTERN void (*RDBlockInfoGetDisposeFunction(const RDBlockInfo *blockInfo))(void *src) {
    if (blockInfo->flags & RDBlockInfoFlagHasCopyDispose)
        return blockInfo->descriptor->dispose;
    else
        return NULL;
}

RD_EXTERN void (*RDBlockInfoGetCopyFunction(const RDBlockInfo *blockInfo))(void *dst, void *src) {
    if (blockInfo->flags & RDBlockInfoFlagHasCopyDispose)
        return blockInfo->descriptor->copy;
    else
        return NULL;
}

RD_EXTERN size_t RDBlockInfoGetInstanceSize(const RDBlockInfo *blockInfo) {
    return blockInfo->descriptor->size;
}

RD_EXTERN RDBlockKind RDBlockGetKind(id block) {
    return RDBlockInfoGetKind(RDGetBlockInfo(block));
}

RD_EXTERN const char *_Nullable RDBlockGetObjcSignature(id block) {
    return RDBlockInfoGetObjcSignature(RDGetBlockInfo(block));
}

RD_EXTERN void (*RDBlockGetDisposeFunction(id block))(void *src) {
    return RDBlockInfoGetDisposeFunction(RDGetBlockInfo(block));
}

RD_EXTERN void (*RDBlockGetCopyFunction(id block))(void *dst, void *src) {
    return RDBlockInfoGetCopyFunction(RDGetBlockInfo(block));
}

RD_EXTERN size_t RDBlockGetSize(id block) {
    return RDBlockInfoGetInstanceSize(RDGetBlockInfo(block));
}

RD_EXTERN NSUInteger RDSelectorArgumentsCount(SEL selector) {
    NSUInteger count = 0;
    for (const char *c = sel_getName(selector); c != NULL && *c != '\0'; ++c)
        if (*c == ':')
            ++count;

    return count;
}

RD_EXTERN long RDRetainCount(id _Nullable value) {
    return value ? 0 : CFGetRetainCount((__bridge CFTypeRef)value);
}
