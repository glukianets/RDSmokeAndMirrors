#import "RDCommon.h"

RD_EXTERN RDBlockInfoFlags const RDBlockInfoFlagsRefCountMask = (RDBlockInfoFlags)0xffff;

RD_EXTERN RDBlockInfo *RDBlockInfoOfBlock(id block) {
    return(__bridge RDBlockInfo *)block;
}

RD_EXTERN const char *RDBlockInfoGetObjCSignature(const RDBlockInfo *blockInfo) {
    const char *signature = NULL;

    if (blockInfo->flags & RDBlockInfoFlagHasSignature) {
        char *signaturePtr = (char *)blockInfo->descriptor;
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

RD_EXTERN RDBlockKind RDBlockInfoGetKind(const RDBlockInfo *blockInfo) {
    if (blockInfo->flags & RDBlockInfoFlagIsGlobal || blockInfo->isa == &_NSConcreteGlobalBlock)
        return RDBlockKindGlobal;
    else if (blockInfo->isa == &_NSConcreteStackBlock)
        return RDBlockKindStack;
    else
        return RDBlockKindMalloc;
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
